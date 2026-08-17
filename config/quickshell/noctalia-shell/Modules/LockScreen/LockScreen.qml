import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.Commons
import qs.Services.Compositor
import qs.Services.Hardware
import qs.Services.Keyboard
import qs.Services.Media
import qs.Services.UI
import qs.Widgets

Loader {
  id: root
  active: false

  // Synced Niri window shader state
  property string currentEffect: "ink-splash"
  property int animDuration: 500

  function queryShaderState() {
    shaderStateProbe.running = false;
    shaderStateProbe.running = true;
  }

  Process {
    id: shaderStateProbe
    command: ["sh", "-c", "cat /tmp/niri-shader-state 2>/dev/null || cat $HOME/shaders/.current 2>/dev/null || echo 'fade'"]
    stdout: StdioCollector {
      onTextChanged: {
        if (text && text.trim().length > 0) {
          root.currentEffect = text.trim();
        }
      }
    }
  }

  // Continuously track shader state so changes with MOD+SHIFT+S take effect immediately
  Timer {
    interval: 800
    running: true
    repeat: true
    onTriggered: root.queryShaderState()
  }

  // Track if the visualizer should be shown (lockscreen active + media playing + non-compact mode)
  readonly property bool needsSpectrum: root.active && !Settings.data.general.compactLockScreen && Settings.data.audio.visualizerType !== "" && Settings.data.audio.visualizerType !== "none"

  onActiveChanged: {
    if (root.active) {
      root.queryShaderState();
    }
    if (root.active && root.needsSpectrum) {
      SpectrumService.registerComponent("lockscreen");
    } else {
      SpectrumService.unregisterComponent("lockscreen");
    }

    if (root.active) {
      LockKeysService.registerComponent("lockscreen");
    } else {
      LockKeysService.unregisterComponent("lockscreen");
    }
  }

  onNeedsSpectrumChanged: {
    if (root.needsSpectrum) {
      SpectrumService.registerComponent("lockscreen");
    } else {
      SpectrumService.unregisterComponent("lockscreen");
    }
  }

  Component.onCompleted: {
    // Register with panel service
    PanelService.lockScreen = this;
    root.queryShaderState();
  }

  Component.onDestruction: {
    SpectrumService.unregisterComponent("lockscreen");
    LockKeysService.unregisterComponent("lockscreen");
  }

  Timer {
    id: unloadAfterUnlockTimer
    interval: 250
    repeat: false
    onTriggered: root.active = false
  }

  function scheduleUnloadAfterUnlock() {
    unloadAfterUnlockTimer.start();
  }

  sourceComponent: Component {
    Item {
      id: lockContainer

      property var activeContentWrapper: null

      LockContext {
        id: lockContext
        onUnlocked: {
          if (lockContainer.activeContentWrapper) {
            lockContainer.activeContentWrapper.startUnlock();
          } else {
            lockSession.locked = false;
            root.scheduleUnloadAfterUnlock();
          }
          lockContext.currentText = "";
        }
        onFailed: {
          lockContext.currentText = "";
        }
      }

      // Whether any monitor from the user's lockScreenMonitors list is currently connected.
      readonly property bool anyConfiguredMonitorConnected: {
        const configured = Settings.data.general.lockScreenMonitors;
        if (!configured || configured.length === 0)
          return false;
        return (Quickshell.screens || []).some(s => configured.includes(s.name));
      }

      WlSessionLock {
        id: lockSession
        locked: root.active

        WlSessionLockSurface {
          id: lockSurface

          Loader {
            anchors.fill: parent
            active: true
            sourceComponent: (!lockContainer.anyConfiguredMonitorConnected || Settings.data.general.lockScreenMonitors.includes(lockSurface.screen?.name)) ? fullLockScreenComponent : blackScreenComponent
          }

          Component {
            id: fullLockScreenComponent

            Item {
              anchors.fill: parent

              // 1. Permanent pitch black base layer - eliminates any white flash
              Rectangle {
                anchors.fill: parent
                color: "#000000"
                z: -100
              }

              Item {
                id: batteryIndicator

                property bool isReady: BatteryService.batteryReady
                property real percent: BatteryService.batteryPercentage
                property bool charging: BatteryService.batteryCharging
                property bool pluggedIn: BatteryService.batteryPluggedIn
                property bool batteryVisible: isReady
                property string icon: BatteryService.batteryIcon
              }

              Item {
                id: keyboardLayout
                property string currentLayout: KeyboardLayoutService.currentLayout
              }

              // 2. Background with wallpaper, blur, gradient - always solid
              LockScreenBackground {
                id: backgroundComponent
                screen: lockSurface.screen
                z: -50
              }

              // 3. Animated Widgets Wrapper with Multi-Profile Transitions
              Item {
                id: lockContentWrapper
                anchors.fill: parent
                z: 10

                property real animProgress: 0.0
                property real crtYProgress: 1.0
                property real crtXProgress: 1.0
                property real slideYOffset: 0.0
                property bool isClosing: false

                // Category checks for active shader
                readonly property bool isCrt: root.currentEffect === "crt-tv"
                readonly property bool isBounce: root.currentEffect === "bounce" || root.currentEffect === "snap"
                readonly property bool isCircle: root.currentEffect === "circle" || root.currentEffect === "ink-splash" || root.currentEffect === "inkwell-drop" || root.currentEffect === "ripple"
                readonly property bool isSlide: root.currentEffect === "directional" || root.currentEffect === "directional-wipe" || root.currentEffect === "crosshatch" || root.currentEffect === "crosswarp"
                readonly property bool isGlitch: root.currentEffect === "glitch" || root.currentEffect === "pixelate" || root.currentEffect === "voronoi-shatter"

                opacity: isCrt ? (crtXProgress > 0.05 ? 1.0 : 0.0) : animProgress
                y: isSlide ? slideYOffset : 0

                transform: [
                  Scale {
                    origin.x: lockContentWrapper.width / 2
                    origin.y: lockContentWrapper.height / 2
                    xScale: {
                      if (lockContentWrapper.isCrt) return lockContentWrapper.crtXProgress;
                      if (lockContentWrapper.isBounce) return lockContentWrapper.isClosing ? (0.3 + 0.7 * lockContentWrapper.animProgress) : (0.5 + 0.5 * lockContentWrapper.animProgress);
                      if (lockContentWrapper.isCircle) return lockContentWrapper.isClosing ? (1.0 + 0.25 * (1.0 - lockContentWrapper.animProgress)) : (0.85 + 0.15 * lockContentWrapper.animProgress);
                      return lockContentWrapper.isClosing ? (1.0 + 0.06 * (1.0 - lockContentWrapper.animProgress)) : (0.94 + 0.06 * lockContentWrapper.animProgress);
                    }
                    yScale: {
                      if (lockContentWrapper.isCrt) return lockContentWrapper.crtYProgress;
                      if (lockContentWrapper.isBounce) return lockContentWrapper.isClosing ? (0.3 + 0.7 * lockContentWrapper.animProgress) : (0.5 + 0.5 * lockContentWrapper.animProgress);
                      if (lockContentWrapper.isCircle) return lockContentWrapper.isClosing ? (1.0 + 0.25 * (1.0 - lockContentWrapper.animProgress)) : (0.85 + 0.15 * lockContentWrapper.animProgress);
                      return lockContentWrapper.isClosing ? (1.0 + 0.06 * (1.0 - lockContentWrapper.animProgress)) : (0.94 + 0.06 * lockContentWrapper.animProgress);
                    }
                  }
                ]

                // Standard Entrance Animation
                ParallelAnimation {
                  id: standardEnterAnim
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "animProgress"
                    from: 0.0
                    to: 1.0
                    duration: lockContentWrapper.isBounce ? 550 : 400
                    easing.type: lockContentWrapper.isBounce ? Easing.OutBack : Easing.OutCubic
                  }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "slideYOffset"
                    from: -120.0
                    to: 0.0
                    duration: 450
                    easing.type: Easing.OutCubic
                  }
                }

                // CRT-TV Entrance Animation
                SequentialAnimation {
                  id: crtEnterAnim
                  PropertyAction { target: lockContentWrapper; property: "animProgress"; value: 1.0 }
                  PropertyAction { target: lockContentWrapper; property: "crtYProgress"; value: 0.02 }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "crtXProgress"
                    from: 0.01
                    to: 1.0
                    duration: 160
                    easing.type: Easing.OutQuad
                  }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "crtYProgress"
                    from: 0.02
                    to: 1.0
                    duration: 220
                    easing.type: Easing.OutCubic
                  }
                }

                // Standard Exit Animation
                ParallelAnimation {
                  id: standardExitAnim
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "animProgress"
                    from: 1.0
                    to: 0.0
                    duration: lockContentWrapper.isBounce ? 320 : 350
                    easing.type: lockContentWrapper.isBounce ? Easing.InBack : Easing.OutCubic
                  }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "slideYOffset"
                    from: 0.0
                    to: 140.0
                    duration: 350
                    easing.type: Easing.InCubic
                  }
                  onFinished: {
                    lockSession.locked = false;
                    root.active = false;
                    lockContentWrapper.isClosing = false;
                  }
                }

                // CRT-TV Exit Animation
                SequentialAnimation {
                  id: crtExitAnim
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "crtYProgress"
                    from: 1.0
                    to: 0.02
                    duration: 180
                    easing.type: Easing.InCubic
                  }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "crtXProgress"
                    from: 1.0
                    to: 0.0
                    duration: 140
                    easing.type: Easing.InQuad
                  }
                  onFinished: {
                    lockSession.locked = false;
                    root.active = false;
                    lockContentWrapper.isClosing = false;
                  }
                }

                Component.onCompleted: {
                  lockContainer.activeContentWrapper = this;
                  if (isCrt) {
                    crtEnterAnim.start();
                  } else {
                    standardEnterAnim.start();
                  }
                }

                function startUnlock() {
                  isClosing = true;
                  if (isCrt) {
                    crtExitAnim.start();
                  } else {
                    standardExitAnim.start();
                  }
                }

                // Mouse area to trigger focus on cursor movement
                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  acceptedButtons: Qt.NoButton
                  onEntered: {
                    if (passwordInput && !passwordInput.activeFocus) {
                      passwordInput.forceActiveFocus();
                    }
                  }
                }

                // Header with Top Bar (Clock + Battery)
                LockScreenHeader {
                  id: headerComponent
                  batteryIndicator: batteryIndicator
                }



                // Countdown notification
                Rectangle {
                  width: countdownRowLayout.implicitWidth + Style.marginXL * 1.5
                  height: 50
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: (Settings.data.general.compactLockScreen ? 280 : 360) * Style.uiScaleRatio
                  radius: Style.radiusL
                  color: Color.mSurface
                  visible: panelComponent.timerActive
                  opacity: visible ? 1.0 : 0.0

                  RowLayout {
                    id: countdownRowLayout
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginM

                    NIcon {
                      icon: "clock"
                      pointSize: Style.fontSizeXL
                      color: Color.mPrimary
                    }

                    NText {
                      text: I18n.tr("session-menu.action-in-seconds", {
                                      "action": I18n.tr("common." + panelComponent.pendingAction),
                                      "seconds": Math.ceil(panelComponent.timeRemaining / 1000)
                                    })
                      color: Color.mOnSurface
                      pointSize: Style.fontSizeL
                      horizontalAlignment: Text.AlignHCenter
                      font.weight: Style.fontWeightBold
                    }

                    Item {
                      Layout.fillWidth: true
                    }

                    NIconButton {
                      icon: "x"
                      tooltipText: I18n.tr("session-menu.cancel-timer")
                      baseSize: 32
                      colorBg: Qt.alpha(Color.mPrimary, 0.1)
                      colorFg: Color.mPrimary
                      colorBgHover: Color.mPrimary
                      onClicked: panelComponent.cancelTimer()
                    }
                  }

                  Behavior on opacity {
                    NumberAnimation {
                      duration: Style.animationNormal
                      easing.type: Easing.OutCubic
                    }
                  }
                }

                // Hidden input that receives actual text
                TextInput {
                  id: passwordInput
                  width: 0
                  height: 0
                  visible: false
                  enabled: !lockContext.unlockInProgress
                  echoMode: TextInput.Password
                  passwordMaskDelay: 0

                  // Bidirectional sync — avoids a declarative binding which breaks on input
                  onTextChanged: {
                    if (lockContext.currentText !== text)
                      lockContext.currentText = text;
                  }
                  Connections {
                    target: lockContext
                    function onCurrentTextChanged() {
                      if (passwordInput.text !== lockContext.currentText)
                        passwordInput.text = lockContext.currentText;
                    }
                  }

                  Keys.onPressed: function (event) {
                    if (Keybinds.checkKey(event, 'enter', Settings)) {
                      lockContext.tryUnlock();
                      event.accepted = true;
                    }
                    if (Keybinds.checkKey(event, 'escape', Settings) && panelComponent.timerActive) {
                      panelComponent.cancelTimer();
                      event.accepted = true;
                    }
                  }

                  Component.onCompleted: forceActiveFocus()
                }

                // Main panel with password, weather, media, session controls
                LockScreenPanel {
                  id: panelComponent
                  lockControl: lockContext
                  batteryIndicator: batteryIndicator
                  keyboardLayout: keyboardLayout
                  passwordInput: passwordInput
                }
              }
            }
          }

          Component {
            id: blackScreenComponent

            // Black surface for disabled monitors — still captures keyboard for password entry
            Rectangle {
              anchors.fill: parent
              color: "black"

              TextInput {
                id: blackScreenPasswordInput
                width: 0
                height: 0
                visible: false
                enabled: !lockContext.unlockInProgress
                echoMode: TextInput.Password
                passwordMaskDelay: 0

                // Bidirectional sync — avoids a declarative binding which breaks on input
                onTextChanged: {
                  if (lockContext.currentText !== text)
                    lockContext.currentText = text;
                }
                Connections {
                  target: lockContext
                  function onCurrentTextChanged() {
                    if (blackScreenPasswordInput.text !== lockContext.currentText)
                      blackScreenPasswordInput.text = lockContext.currentText;
                  }
                }

                Keys.onPressed: function (event) {
                  if (Keybinds.checkKey(event, 'enter', Settings)) {
                    lockContext.tryUnlock();
                    event.accepted = true;
                  }
                }

                Component.onCompleted: forceActiveFocus()
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onPositionChanged: blackScreenPasswordInput.forceActiveFocus()
              }
            }
          }
        }
      }
    }
  }
}
