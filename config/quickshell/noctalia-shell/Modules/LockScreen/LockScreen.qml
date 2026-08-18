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
      property var activeWrappers: []
      property bool unlockInProgress: false

      LockContext {
        id: lockContext
        onUnlocked: {
          lockContainer.unlockInProgress = true;
          if (lockContainer.activeWrappers && lockContainer.activeWrappers.length > 0) {
            for (let i = 0; i < lockContainer.activeWrappers.length; i++) {
              const w = lockContainer.activeWrappers[i];
              if (w && typeof w.startUnlock === "function") {
                w.startUnlock();
              }
            }
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

              // 3. Animated Widgets Wrapper with Pure CRT-TV Turn-On / Turn-Off
              Item {
                id: lockContentWrapper
                anchors.fill: parent
                z: 10

                property real scaleXVal: 0.005
                property real scaleYVal: 0.01
                property real contentOpacity: 0.0
                property real crtFlashOpacity: 0.0
                property bool isClosing: false

                opacity: lockContentWrapper.contentOpacity

                transform: [
                  Scale {
                    origin.x: lockContentWrapper.width / 2
                    origin.y: lockContentWrapper.height / 2
                    xScale: lockContentWrapper.scaleXVal
                    yScale: lockContentWrapper.scaleYVal
                  }
                ]

                // CRT Phosphor Flash Overlay
                Rectangle {
                  anchors.fill: parent
                  color: "#ffffff"
                  opacity: lockContentWrapper.crtFlashOpacity * 0.45
                  visible: opacity > 0.01
                  z: 998
                }

                // CRT Horizontal Line Beam
                Rectangle {
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width * lockContentWrapper.scaleXVal
                  height: 3
                  color: "#ffffff"
                  visible: lockContentWrapper.crtFlashOpacity > 0.05
                  opacity: lockContentWrapper.crtFlashOpacity
                  z: 999
                }

                // CRT-TV Entrance Animation (Turn ON)
                SequentialAnimation {
                  id: crtEnterAnim
                  PropertyAction { target: lockContentWrapper; property: "contentOpacity"; value: 1.0 }
                  PropertyAction { target: lockContentWrapper; property: "scaleXVal"; value: 0.005 }
                  PropertyAction { target: lockContentWrapper; property: "scaleYVal"; value: 0.01 }
                  PropertyAction { target: lockContentWrapper; property: "crtFlashOpacity"; value: 0.9 }

                  // Stage 1: Expand horizontal ray (300ms)
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "scaleXVal"
                    from: 0.005
                    to: 1.0
                    duration: 300
                    easing.type: Easing.OutQuad
                  }
                  // Stage 2: Expand vertical height into full screen (420ms)
                  ParallelAnimation {
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "scaleYVal"
                      from: 0.01
                      to: 1.0
                      duration: 420
                      easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "crtFlashOpacity"
                      from: 0.9
                      to: 0.0
                      duration: 500
                      easing.type: Easing.OutQuad
                    }
                  }
                }

                // CRT-TV Exit Animation (Turn OFF)
                SequentialAnimation {
                  id: crtExitAnim
                  // Stage 1: Collapse vertical height into a thin beam (320ms)
                  ParallelAnimation {
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "scaleYVal"
                      from: 1.0
                      to: 0.01
                      duration: 320
                      easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "crtFlashOpacity"
                      from: 0.0
                      to: 0.85
                      duration: 260
                      easing.type: Easing.InQuad
                    }
                  }
                  // Stage 2: Collapse horizontal beam into a dot & fade out (250ms)
                  ParallelAnimation {
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "scaleXVal"
                      from: 1.0
                      to: 0.0
                      duration: 250
                      easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "crtFlashOpacity"
                      from: 0.85
                      to: 0.0
                      duration: 250
                      easing.type: Easing.InQuad
                    }
                  }
                  PropertyAction { target: lockContentWrapper; property: "contentOpacity"; value: 0.0 }
                  ScriptAction {
                    script: {
                      lockSession.locked = false;
                      root.active = false;
                      lockContentWrapper.isClosing = false;
                    }
                  }
                }

                Component.onCompleted: {
                  if (lockContainer.activeWrappers) {
                    lockContainer.activeWrappers.push(this);
                  }
                  crtEnterAnim.start();
                }

                Component.onDestruction: {
                  if (lockContainer.activeWrappers) {
                    const idx = lockContainer.activeWrappers.indexOf(this);
                    if (idx !== -1) {
                      lockContainer.activeWrappers.splice(idx, 1);
                    }
                  }
                }

                function startUnlock() {
                  isClosing = true;
                  crtExitAnim.start();
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
