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

  property string currentEffect: "overexposure"

  FileView {
    id: shaderStateWatcher
    path: Quickshell.env("HOME") + "/shaders/.current"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var e = text() ? text().trim() : "";
      if (e) root.currentEffect = e;
    }
    onFileChanged: {
      var e = text() ? text().trim() : "";
      if (e) root.currentEffect = e;
    }
  }

  // Track if the visualizer should be shown (lockscreen active + media playing + non-compact mode)
  readonly property bool needsSpectrum: root.active && !Settings.data.general.compactLockScreen && Settings.data.audio.visualizerType !== "" && Settings.data.audio.visualizerType !== "none"

  onActiveChanged: {
    if (root.active) {
      if (shaderStateWatcher && typeof shaderStateWatcher.reload === "function") {
        try { shaderStateWatcher.reload(); } catch(e) {}
      }
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

              // 2. Background with wallpaper, blur, gradient - synchronized with lock animation
              LockScreenBackground {
                id: backgroundComponent
                screen: lockSurface.screen
                opacity: lockContentWrapper.contentOpacity
                z: -50

                layer.enabled: lockContentWrapper.useGpuShader
                layer.effect: ShaderEffect {
                  property real progress: lockContentWrapper.shaderProgress
                  property int effectType: lockContentWrapper.activeShaderId
                  fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/lock_master.frag.qsb")
                }
              }

              // Overexposure Flash Overlay
              Rectangle {
                id: overexposureOverlay
                anchors.fill: parent
                color: "#ffffff"
                opacity: 0.0
                visible: opacity > 0.005
                z: 998
              }

              // CRT Beam Line Overlay
              Rectangle {
                id: crtLineBeam
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * lockContentWrapper.scaleXVal
                height: 3
                color: "#ffffff"
                opacity: lockContentWrapper.crtFlashOpacity
                visible: opacity > 0.05
                z: 999
              }

              // CRT Phosphor Flash Overlay
              Rectangle {
                id: crtFlashOverlay
                anchors.fill: parent
                color: "#ffffff"
                opacity: lockContentWrapper.crtFlashOpacity * 0.45
                visible: opacity > 0.01
                z: 997
              }

              // 3. Animated Widgets Wrapper (Dynamic based on active niri-shader effect)
              Item {
                id: lockContentWrapper
                anchors.fill: parent
                z: 10

                property real contentOpacity: 0.0
                property real scaleXVal: 1.0
                property real scaleYVal: 1.0
                property real translateXVal: 0.0
                property real translateYVal: 0.0
                property real crtFlashOpacity: 0.0
                property real shaderProgress: 1.0
                property int activeShaderId: 0
                property bool useGpuShader: false
                property bool isClosing: false

                opacity: lockContentWrapper.contentOpacity

                layer.enabled: useGpuShader
                layer.effect: ShaderEffect {
                  property real progress: lockContentWrapper.shaderProgress
                  property int effectType: lockContentWrapper.activeShaderId
                  fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/lock_master.frag.qsb")
                }

                transform: [
                  Scale {
                    origin.x: lockContentWrapper.width / 2
                    origin.y: lockContentWrapper.height / 2
                    xScale: lockContentWrapper.scaleXVal
                    yScale: lockContentWrapper.scaleYVal
                  },
                  Translate {
                    x: lockContentWrapper.translateXVal
                    y: lockContentWrapper.translateYVal
                  }
                ]

                function finishUnlock() {
                  lockSession.locked = false;
                  root.active = false;
                  lockContentWrapper.isClosing = false;
                }

                // ── EFFECT 1: Overexposure / Bloom ─────────────────────
                ParallelAnimation {
                  id: overexposureEnterAnim
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "contentOpacity"
                    from: 0.0
                    to: 1.0
                    duration: 500
                    easing.type: Easing.OutCubic
                  }
                  SequentialAnimation {
                    NumberAnimation {
                      target: overexposureOverlay
                      property: "opacity"
                      from: 0.0
                      to: 0.45
                      duration: 200
                      easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                      target: overexposureOverlay
                      property: "opacity"
                      from: 0.45
                      to: 0.0
                      duration: 300
                      easing.type: Easing.OutCubic
                    }
                  }
                }

                SequentialAnimation {
                  id: overexposureExitAnim
                  ParallelAnimation {
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "contentOpacity"
                      from: 1.0
                      to: 0.0
                      duration: 500
                      easing.type: Easing.OutCubic
                    }
                    SequentialAnimation {
                      NumberAnimation {
                        target: overexposureOverlay
                        property: "opacity"
                        from: 0.0
                        to: 0.40
                        duration: 180
                        easing.type: Easing.OutQuad
                      }
                      NumberAnimation {
                        target: overexposureOverlay
                        property: "opacity"
                        from: 0.40
                        to: 0.0
                        duration: 320
                        easing.type: Easing.InQuad
                      }
                    }
                  }
                  ScriptAction { script: lockContentWrapper.finishUnlock() }
                }

                // ── EFFECT 2: CRT-TV ─────────────────────────────────────
                SequentialAnimation {
                  id: crtEnterAnim
                  PropertyAction { target: lockContentWrapper; property: "contentOpacity"; value: 1.0 }
                  PropertyAction { target: lockContentWrapper; property: "scaleXVal"; value: 0.005 }
                  PropertyAction { target: lockContentWrapper; property: "scaleYVal"; value: 0.01 }
                  PropertyAction { target: lockContentWrapper; property: "crtFlashOpacity"; value: 0.9 }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "scaleXVal"
                    from: 0.005
                    to: 1.0
                    duration: 220
                    easing.type: Easing.OutQuad
                  }
                  ParallelAnimation {
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "scaleYVal"
                      from: 0.01
                      to: 1.0
                      duration: 300
                      easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "crtFlashOpacity"
                      from: 0.9
                      to: 0.0
                      duration: 380
                      easing.type: Easing.OutQuad
                    }
                  }
                }

                SequentialAnimation {
                  id: crtExitAnim
                  ParallelAnimation {
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "scaleYVal"
                      from: 1.0
                      to: 0.01
                      duration: 230
                      easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "crtFlashOpacity"
                      from: 0.0
                      to: 0.85
                      duration: 200
                      easing.type: Easing.InQuad
                    }
                  }
                  ParallelAnimation {
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "scaleXVal"
                      from: 1.0
                      to: 0.0
                      duration: 180
                      easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "crtFlashOpacity"
                      from: 0.85
                      to: 0.0
                      duration: 180
                      easing.type: Easing.InQuad
                    }
                  }
                  PropertyAction { target: lockContentWrapper; property: "contentOpacity"; value: 0.0 }
                  ScriptAction { script: lockContentWrapper.finishUnlock() }
                }

                // ── EFFECT 3: Bounce / Snap ──────────────────────────────
                ParallelAnimation {
                  id: bounceEnterAnim
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "contentOpacity"
                    from: 0.0
                    to: 1.0
                    duration: 350
                    easing.type: Easing.OutCubic
                  }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "scaleXVal"
                    from: 0.82
                    to: 1.0
                    duration: 520
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.35
                  }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "scaleYVal"
                    from: 0.82
                    to: 1.0
                    duration: 520
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.35
                  }
                }

                SequentialAnimation {
                  id: bounceExitAnim
                  ParallelAnimation {
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "contentOpacity"
                      from: 1.0
                      to: 0.0
                      duration: 320
                      easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "scaleXVal"
                      from: 1.0
                      to: 0.80
                      duration: 320
                      easing.type: Easing.InBack
                    }
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "scaleYVal"
                      from: 1.0
                      to: 0.80
                      duration: 320
                      easing.type: Easing.InBack
                    }
                  }
                  ScriptAction { script: lockContentWrapper.finishUnlock() }
                }

                // ── EFFECT 4: Glitch / Static / Voronoi ──────────────────
                SequentialAnimation {
                  id: glitchEnterAnim
                  PropertyAction { target: lockContentWrapper; property: "contentOpacity"; value: 0.8 }
                  PropertyAction { target: lockContentWrapper; property: "translateXVal"; value: 8 }
                  PauseAnimation { duration: 50 }
                  PropertyAction { target: lockContentWrapper; property: "contentOpacity"; value: 0.2 }
                  PropertyAction { target: lockContentWrapper; property: "translateXVal"; value: -6 }
                  PropertyAction { target: lockContentWrapper; property: "translateYVal"; value: 4 }
                  PauseAnimation { duration: 40 }
                  PropertyAction { target: lockContentWrapper; property: "contentOpacity"; value: 0.95 }
                  PropertyAction { target: lockContentWrapper; property: "translateXVal"; value: 4 }
                  PropertyAction { target: lockContentWrapper; property: "translateYVal"; value: -2 }
                  PauseAnimation { duration: 50 }
                  PropertyAction { target: lockContentWrapper; property: "translateXVal"; value: 0 }
                  PropertyAction { target: lockContentWrapper; property: "translateYVal"; value: 0 }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "contentOpacity"
                    from: 0.95
                    to: 1.0
                    duration: 120
                    easing.type: Easing.OutQuad
                  }
                }

                SequentialAnimation {
                  id: glitchExitAnim
                  PropertyAction { target: lockContentWrapper; property: "contentOpacity"; value: 0.4 }
                  PropertyAction { target: lockContentWrapper; property: "translateXVal"; value: -8 }
                  PauseAnimation { duration: 40 }
                  PropertyAction { target: lockContentWrapper; property: "contentOpacity"; value: 0.85 }
                  PropertyAction { target: lockContentWrapper; property: "translateXVal"; value: 6 }
                  PauseAnimation { duration: 40 }
                  PropertyAction { target: lockContentWrapper; property: "contentOpacity"; value: 0.0 }
                  PropertyAction { target: lockContentWrapper; property: "translateXVal"; value: 0 }
                  ScriptAction { script: lockContentWrapper.finishUnlock() }
                }

                // ── EFFECT 5: Native Master GPU Fragment Shader (Reverse Engineered from Niri) ──
                ParallelAnimation {
                  id: gpuEnterAnim
                  PropertyAction { target: lockContentWrapper; property: "useGpuShader"; value: true }
                  PropertyAction { target: lockContentWrapper; property: "contentOpacity"; value: 1.0 }
                  PropertyAction { target: lockContentWrapper; property: "shaderProgress"; value: 0.0 }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "shaderProgress"
                    from: 0.0
                    to: 1.0
                    duration: 500
                    easing.type: Easing.OutCubic
                  }
                }

                SequentialAnimation {
                  id: gpuExitAnim
                  PropertyAction { target: lockContentWrapper; property: "useGpuShader"; value: true }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "shaderProgress"
                    from: 1.0
                    to: 0.0
                    duration: 450
                    easing.type: Easing.OutCubic
                  }
                  ScriptAction { script: lockContentWrapper.finishUnlock() }
                }

                readonly property alias perlinEnterAnim: gpuEnterAnim
                readonly property alias perlinExitAnim: gpuExitAnim

                // ── EFFECT 6: Circle / Polar / Flyeye ────────────────────
                ParallelAnimation {
                  id: circleEnterAnim
                  PropertyAction { target: lockContentWrapper; property: "scaleXVal"; value: 0.35 }
                  PropertyAction { target: lockContentWrapper; property: "scaleYVal"; value: 0.35 }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "scaleXVal"
                    from: 0.35
                    to: 1.0
                    duration: 480
                    easing.type: Easing.OutExpo
                  }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "scaleYVal"
                    from: 0.35
                    to: 1.0
                    duration: 480
                    easing.type: Easing.OutExpo
                  }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "contentOpacity"
                    from: 0.0
                    to: 1.0
                    duration: 400
                    easing.type: Easing.OutQuad
                  }
                }

                SequentialAnimation {
                  id: circleExitAnim
                  ParallelAnimation {
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "scaleXVal"
                      from: 1.0
                      to: 0.30
                      duration: 350
                      easing.type: Easing.InExpo
                    }
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "scaleYVal"
                      from: 1.0
                      to: 0.30
                      duration: 350
                      easing.type: Easing.InExpo
                    }
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "contentOpacity"
                      from: 1.0
                      to: 0.0
                      duration: 320
                      easing.type: Easing.InQuad
                    }
                  }
                  ScriptAction { script: lockContentWrapper.finishUnlock() }
                }

                // ── EFFECT 7: Directional / Slide ────────────────────────
                ParallelAnimation {
                  id: directionalEnterAnim
                  PropertyAction { target: lockContentWrapper; property: "translateYVal"; value: -70 }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "translateYVal"
                    from: -70
                    to: 0
                    duration: 450
                    easing.type: Easing.OutCubic
                  }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "contentOpacity"
                    from: 0.0
                    to: 1.0
                    duration: 400
                    easing.type: Easing.OutQuad
                  }
                }

                SequentialAnimation {
                  id: directionalExitAnim
                  ParallelAnimation {
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "translateYVal"
                      from: 0
                      to: 70
                      duration: 350
                      easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "contentOpacity"
                      from: 1.0
                      to: 0.0
                      duration: 320
                      easing.type: Easing.InQuad
                    }
                  }
                  ScriptAction { script: lockContentWrapper.finishUnlock() }
                }

                // ── EFFECT 8: Ripple / Ink-splash / Droplet ──────────────
                ParallelAnimation {
                  id: rippleEnterAnim
                  PropertyAction { target: lockContentWrapper; property: "scaleXVal"; value: 0.75 }
                  PropertyAction { target: lockContentWrapper; property: "scaleYVal"; value: 0.75 }
                  SequentialAnimation {
                    ParallelAnimation {
                      NumberAnimation {
                        target: lockContentWrapper
                        property: "scaleXVal"
                        from: 0.75
                        to: 1.04
                        duration: 300
                        easing.type: Easing.OutQuad
                      }
                      NumberAnimation {
                        target: lockContentWrapper
                        property: "scaleYVal"
                        from: 0.75
                        to: 1.04
                        duration: 300
                        easing.type: Easing.OutQuad
                      }
                    }
                    ParallelAnimation {
                      NumberAnimation {
                        target: lockContentWrapper
                        property: "scaleXVal"
                        from: 1.04
                        to: 1.0
                        duration: 180
                        easing.type: Easing.InOutQuad
                      }
                      NumberAnimation {
                        target: lockContentWrapper
                        property: "scaleYVal"
                        from: 1.04
                        to: 1.0
                        duration: 180
                        easing.type: Easing.InOutQuad
                      }
                    }
                  }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "contentOpacity"
                    from: 0.0
                    to: 1.0
                    duration: 350
                    easing.type: Easing.OutQuad
                  }
                }

                SequentialAnimation {
                  id: rippleExitAnim
                  ParallelAnimation {
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "scaleXVal"
                      from: 1.0
                      to: 0.70
                      duration: 350
                      easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "scaleYVal"
                      from: 1.0
                      to: 0.70
                      duration: 350
                      easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "contentOpacity"
                      from: 1.0
                      to: 0.0
                      duration: 320
                      easing.type: Easing.InQuad
                    }
                  }
                  ScriptAction { script: lockContentWrapper.finishUnlock() }
                }

                // ── EFFECT 9: Pixel / Quantized Dissolve ─────────────────
                SequentialAnimation {
                  id: pixelEnterAnim
                  PropertyAction { target: lockContentWrapper; property: "contentOpacity"; value: 0.0 }
                  PauseAnimation { duration: 40 }
                  PropertyAction { target: lockContentWrapper; property: "contentOpacity"; value: 0.22 }
                  PauseAnimation { duration: 60 }
                  PropertyAction { target: lockContentWrapper; property: "contentOpacity"; value: 0.48 }
                  PauseAnimation { duration: 60 }
                  PropertyAction { target: lockContentWrapper; property: "contentOpacity"; value: 0.75 }
                  PauseAnimation { duration: 60 }
                  PropertyAction { target: lockContentWrapper; property: "contentOpacity"; value: 1.0 }
                }

                SequentialAnimation {
                  id: pixelExitAnim
                  PropertyAction { target: lockContentWrapper; property: "contentOpacity"; value: 0.75 }
                  PauseAnimation { duration: 50 }
                  PropertyAction { target: lockContentWrapper; property: "contentOpacity"; value: 0.45 }
                  PauseAnimation { duration: 50 }
                  PropertyAction { target: lockContentWrapper; property: "contentOpacity"; value: 0.15 }
                  PauseAnimation { duration: 40 }
                  PropertyAction { target: lockContentWrapper; property: "contentOpacity"; value: 0.0 }
                  ScriptAction { script: lockContentWrapper.finishUnlock() }
                }

                // ── EFFECT 10: Smooth Fade (Default fallback) ────────────
                ParallelAnimation {
                  id: fadeEnterAnim
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "contentOpacity"
                    from: 0.0
                    to: 1.0
                    duration: 450
                    easing.type: Easing.OutCubic
                  }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "scaleXVal"
                    from: 0.96
                    to: 1.0
                    duration: 450
                    easing.type: Easing.OutCubic
                  }
                  NumberAnimation {
                    target: lockContentWrapper
                    property: "scaleYVal"
                    from: 0.96
                    to: 1.0
                    duration: 450
                    easing.type: Easing.OutCubic
                  }
                }

                SequentialAnimation {
                  id: fadeExitAnim
                  ParallelAnimation {
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "contentOpacity"
                      from: 1.0
                      to: 0.0
                      duration: 400
                      easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "scaleXVal"
                      from: 1.0
                      to: 0.96
                      duration: 400
                      easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                      target: lockContentWrapper
                      property: "scaleYVal"
                      from: 1.0
                      to: 0.96
                      duration: 400
                      easing.type: Easing.OutCubic
                    }
                  }
                  ScriptAction { script: lockContentWrapper.finishUnlock() }
                }

                function resetProperties() {
                  lockContentWrapper.useGpuShader = false;
                  lockContentWrapper.shaderProgress = 1.0;
                  lockContentWrapper.scaleXVal = 1.0;
                  lockContentWrapper.scaleYVal = 1.0;
                  lockContentWrapper.translateXVal = 0.0;
                  lockContentWrapper.translateYVal = 0.0;
                  lockContentWrapper.crtFlashOpacity = 0.0;
                  if (overexposureOverlay) overexposureOverlay.opacity = 0.0;
                }

                function getShaderIdForEffect(name) {
                  name = (name || "").toLowerCase().trim();
                  switch (name) {
                    case "perlin":
                    case "heat-melt":
                    case "plasma-flow":
                      return 0; // Perlin 2D Noise
                    case "circle":
                      return 1; // Circle Iris
                    case "polar-function":
                      return 2; // Polar 5-segment Flower
                    case "glitch":
                    case "static-fade":
                      return 3; // Glitch RGB Chromatic Aberration & Slice
                    case "pixelate":
                    case "pixelfade-wave":
                      return 4; // Pixelate Wave
                    case "randomsquares":
                      return 5; // Random Squares
                    case "dissolve":
                    case "smoke":
                      return 6; // FBM Smoke / Dissolve
                    case "ripple":
                      return 7; // Ripple wave
                    case "flyeye":
                      return 8; // Flyeye lens
                    case "overexposure":
                    case "fadecolor":
                    case "colour-distance":
                    case "crazy-parametric":
                      return 9; // Overexposure Bloom
                    case "directional":
                    case "directional-wipe":
                      return 10; // Directional Slide
                    case "voronoi-shatter":
                      return 11; // Voronoi Shatter
                    case "wave-warp":
                    case "glass-warp":
                    case "soft-warp-fade":
                      return 12; // Wave Warp
                    case "polka-dots-curtain":
                    case "ink-splash":
                    case "inkwell-drop":
                      return 13; // Polka Dots / Droplet
                    case "bounce":
                    case "snap":
                      return 14; // Bounce Wave
                    case "crosshatch":
                    case "crosswarp":
                    case "morph":
                    case "fade":
                    default:
                      return 15; // Smooth Fade
                  }
                }

                function getActiveShaderName() {
                  let eff = "";
                  if (shaderStateWatcher && typeof shaderStateWatcher.text === "function") {
                    try {
                      let t = shaderStateWatcher.text();
                      if (t && t.trim()) eff = t.trim();
                    } catch(e) {}
                  }
                  if (!eff && root.currentEffect) {
                    eff = root.currentEffect.trim();
                  }
                  return (eff || "fade").toLowerCase();
                }

                // Trigger entrance animation based on current active effect
                function startEnter() {
                  resetProperties();
                  const eff = getActiveShaderName();
                  Logger.i("LockScreen", "Starting enter animation for shader:", eff);

                  // Keep classic CRT-TV animation intact as requested
                  if (eff === "crt-tv") {
                    crtEnterAnim.start();
                    return;
                  }

                  // All other 33 shaders run on reverse-engineered hardware GPU shader
                  lockContentWrapper.activeShaderId = getShaderIdForEffect(eff);
                  gpuEnterAnim.start();
                }

                function startUnlock() {
                  isClosing = true;
                  const eff = getActiveShaderName();
                  Logger.i("LockScreen", "Starting exit animation for shader:", eff);

                  // Keep classic CRT-TV animation intact as requested
                  if (eff === "crt-tv") {
                    crtExitAnim.start();
                    return;
                  }

                  // All other shaders run on reverse-engineered hardware GPU shader
                  lockContentWrapper.activeShaderId = getShaderIdForEffect(eff);
                  gpuExitAnim.start();
                }

                Component.onCompleted: {
                  if (lockContainer.activeWrappers) {
                    lockContainer.activeWrappers.push(this);
                  }
                  startEnter();
                }

                Component.onDestruction: {
                  if (lockContainer.activeWrappers) {
                    const idx = lockContainer.activeWrappers.indexOf(this);
                    if (idx !== -1) {
                      lockContainer.activeWrappers.splice(idx, 1);
                    }
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
