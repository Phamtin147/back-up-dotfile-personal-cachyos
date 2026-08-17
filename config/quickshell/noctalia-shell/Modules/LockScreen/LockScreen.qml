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

  // Live file watcher for Niri shader state - 0ms latency
  FileView {
    id: shaderStateFile
    path: "/tmp/niri-shader-state"
    watchChanges: true
    onLoaded: {
      const txt = String(shaderStateFile.text() || "").trim();
      if (txt.length > 0) {
        root.currentEffect = txt;
      }
    }
  }

  property string currentEffect: "bounce"
  property int animDuration: 500

  // Track if the visualizer should be shown (lockscreen active + media playing + non-compact mode)
  readonly property bool needsSpectrum: root.active && !Settings.data.general.compactLockScreen && Settings.data.audio.visualizerType !== "" && Settings.data.audio.visualizerType !== "none"

  onActiveChanged: {
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
                transformOrigin: Item.Center

                property real animProgress: 0.0
                property real slideYOffset: 0.0
                property real crtFlashOpacity: 0.0
                property bool isClosing: false

                // Category checks for active shader
                readonly property string activeEff: root.currentEffect
                readonly property bool isCrt: activeEff === "crt-tv"
                readonly property bool isBounce: activeEff === "bounce" || activeEff === "snap"
                readonly property bool isCircle: activeEff === "circle" || activeEff === "ink-splash" || activeEff === "inkwell-drop" || activeEff === "ripple"
                readonly property bool isSlide: activeEff === "directional" || activeEff === "directional-wipe" || activeEff === "crosshatch" || activeEff === "crosswarp"

                opacity: animProgress
                y: isSlide ? slideYOffset : 0

                scale: {
                  if (lockContentWrapper.isBounce) {
                    return isClosing ? (0.2 + 0.8 * lockContentWrapper.animProgress) : (0.15 + 0.85 * lockContentWrapper.animProgress);
                  }
                  if (lockContentWrapper.isCircle) {
                    return isClosing ? (1.0 + 0.5 * (1.0 - lockContentWrapper.animProgress)) : (0.25 + 0.75 * lockContentWrapper.animProgress);
                  }
                  if (lockContentWrapper.isCrt) {
                    return isClosing ? (0.05 + 0.95 * lockContentWrapper.animProgress) : (0.05 + 0.95 * lockContentWrapper.animProgress);
                  }
                  // Default / smooth scale
                  return isClosing ? (1.0 + 0.08 * (1.0 - lockContentWrapper.animProgress)) : (0.92 + 0.08 * lockContentWrapper.animProgress);
                }

                // CRT Phosphor Flash Overlay
                Rectangle {
                  anchors.fill: parent
                  color: "#ffffff"
                  opacity: lockContentWrapper.crtFlashOpacity
                  visible: opacity > 0.01
                  z: 999
                }

                // Standard Entrance Animation
                ParallelAnimation {
                  id: standardEnterAnim
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "animProgress"
                    from: 0.0
                    to: 1.0
                    duration: lockContentWrapper.isBounce ? 600 : (lockContentWrapper.isCircle ? 500 : 400)
                    easing.type: lockContentWrapper.isBounce ? Easing.OutBack : (lockContentWrapper.isCircle ? Easing.OutExpo : Easing.OutCubic)
                  }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "slideYOffset"
                    from: -300.0
                    to: 0.0
                    duration: 500
                    easing.type: Easing.OutCubic
                  }
                }

                // CRT-TV Entrance Animation
                SequentialAnimation {
                  id: crtEnterAnim
                  ParallelAnimation {
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "animProgress"
                      from: 0.0
                      to: 1.0
                      duration: 350
                      easing.type: Easing.OutExpo
                    }
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "crtFlashOpacity"
                      from: 0.8
                      to: 0.0
                      duration: 400
                      easing.type: Easing.OutQuad
                    }
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
                    duration: lockContentWrapper.isBounce ? 350 : 350
                    easing.type: lockContentWrapper.isBounce ? Easing.InBack : Easing.InCubic
                  }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "slideYOffset"
                    from: 0.0
                    to: 300.0
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
                  ParallelAnimation {
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "crtFlashOpacity"
                      from: 0.0
                      to: 0.6
                      duration: 120
                      easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "animProgress"
                      from: 1.0
                      to: 0.0
                      duration: 250
                      easing.type: Easing.InExpo
                    }
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
