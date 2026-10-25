import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.Media
import qs.Services.UI
import qs.Widgets
import qs.Widgets.AudioSpectrum

Item {
  id: root

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  // Explicit screenName property ensures reactive binding when screen changes
  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVerticalBar: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0 && screenName) {
      var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
      if (widgets && sectionWidgetIndex < widgets.length) {
        return widgets[sectionWidgetIndex];
      }
    }
    return {};
  }

  // Resolve settings: try user settings or defaults from BarWidgetRegistry
  readonly property bool fillGap: widgetSettings.fillGap !== undefined ? widgetSettings.fillGap : (section === "center")
  readonly property int configuredWidth: widgetSettings.width !== undefined ? widgetSettings.width : (widgetMetadata.width || 400)
  readonly property bool hideWhenIdle: widgetSettings.hideWhenIdle !== undefined ? widgetSettings.hideWhenIdle : widgetMetadata.hideWhenIdle
  readonly property string colorName: widgetSettings.colorName !== undefined ? widgetSettings.colorName : widgetMetadata.colorName
  readonly property bool idleAnimation: widgetSettings.idleAnimation !== undefined ? widgetSettings.idleAnimation : true
  readonly property string idleStyle: widgetSettings.idleStyle !== undefined ? widgetSettings.idleStyle : "aurora"

  readonly property bool isGapFillActive: fillGap && section === "center" && !isVerticalBar && root.parent && root.parent.width > 50
  readonly property int visualizerWidth: isGapFillActive ? root.parent.width : configuredWidth

  readonly property color fillColor: Color.resolveColorKey(colorName)

  readonly property bool isVisualizerConfigured: currentVisualizerType !== "" && currentVisualizerType !== "none"
  readonly property bool shouldShow: isVisualizerConfigured && (!hideWhenIdle || !SpectrumService.isIdle || MediaService.isPlaying)

  // State for idle sine wave animation & audio reactivity
  property real idlePhase: 0.0
  property real activity: 0.0
  property var currentLevels: []
  property real _lastTime: 0.0

  readonly property int targetBandCount: {
    var w = root.contentWidth > 0 ? root.contentWidth : (root.width > 0 ? root.width : root.configuredWidth);
    if (Settings.data.audio.spectrumMirrored) {
      return Math.max(32, Math.min(128, Math.round(w / 14)));
    } else {
      return Math.max(48, Math.min(160, Math.round(w / 7)));
    }
  }

  function sampleAudioBand(raw, u) {
    if (!raw || raw.length === 0) return 0.0;
    var pos = u * (raw.length - 1);
    var i0 = Math.floor(pos);
    var i1 = Math.min(raw.length - 1, i0 + 1);
    var f = pos - i0;
    var v0 = (raw[i0] !== undefined) ? raw[i0] : 0.0;
    var v1 = (raw[i1] !== undefined) ? raw[i1] : 0.0;
    return v0 + (v1 - v0) * f;
  }

  property var visualizerValues: []

  function updateVisualizerFrame() {
    var now = Date.now();
    var dt = root._lastTime > 0 ? (now - root._lastTime) / 1000.0 : 0.016;
    root._lastTime = now;
    if (dt <= 0 || dt > 0.1) dt = 0.016;

    // Advance idle wave phase
    root.idlePhase += dt * 3.0;
    if (root.idlePhase > 6283.18) {
      root.idlePhase -= 6283.18;
    }

    // Audio active check
    var raw = SpectrumService.values;
    var energy = 0.0;
    if (raw && raw.length > 0) {
      var sum = 0.0;
      for (var k = 0; k < raw.length; k++) {
        sum += (raw[k] || 0.0);
      }
      energy = sum / raw.length;
    }
    var audioActive = (!SpectrumService.isIdle && energy > 0.005) || (energy > 0.012) || MediaService.isPlaying;

    // Smooth transition between idle and active
    var targetActivity = audioActive ? 1.0 : 0.0;
    var speed = targetActivity > root.activity ? 15.0 : 1.8;
    root.activity += (targetActivity - root.activity) * Math.min(1.0, dt * speed);
    if (Math.abs(root.activity - targetActivity) < 0.005) {
      root.activity = targetActivity;
    }

    var n = root.targetBandCount;
    if (n < 8) n = 32;

    if (!root.currentLevels || root.currentLevels.length !== n) {
      root.currentLevels = new Array(n).fill(0.0);
    }

    var isMirrored = Settings.data.audio.spectrumMirrored;
    var out = new Array(n);

    var style = root.idleStyle; // "aurora", "pulse", "scanner", "shimmer", "wave"

    for (var i = 0; i < n; i++) {
      // Coordinate u: 0 at center, 1 at edges
      var u = isMirrored ? (i / Math.max(1, n - 1)) : (Math.abs(i - (n - 1) * 0.5) / Math.max(1, (n - 1) * 0.5));
      var uLinear = i / Math.max(1, n - 1); // 0 at far left, 1 at far right

      var rawVal = sampleAudioBand(raw, u);
      var idleHeight = 0.0;

      if (style === "pulse") {
        // Ryoku-inspired heartbeat pulse surging from center
        var pulseProgress = (root.idlePhase * 0.32) % 1.0;
        var pulseCenter = pulseProgress * 1.35;
        var distP = Math.abs(u - pulseCenter);
        var pulseEnv = Math.max(0.0, 1.0 - distP / 0.18);
        pulseEnv = Math.pow(pulseEnv, 1.8);
        var restSliver = 0.06;
        var surgeAmp = 0.40 * Math.cos(u * 1.2);
        idleHeight = restSliver + pulseEnv * surgeAmp;
      } else if (style === "scanner") {
        // Cyberpunk sweeping beam moving across the bar
        var scanX = 0.5 + 0.45 * Math.sin(root.idlePhase * 0.85);
        var distS = Math.abs(uLinear - scanX);
        var beam = Math.exp(-Math.pow(distS / 0.08, 2.0));
        var beamGlow = Math.exp(-Math.pow(distS / 0.22, 2.0)) * 0.14;
        idleHeight = 0.06 + 0.45 * beam + beamGlow;
      } else if (style === "shimmer") {
        // Lo-fi sparkling fireflies / water ripples
        var sm1 = 0.5 + 0.5 * Math.sin(u * 16.0 + root.idlePhase * 2.2);
        var sm2 = 0.5 + 0.5 * Math.cos(u * 28.0 - root.idlePhase * 1.6);
        var sm3 = 0.5 + 0.5 * Math.sin(root.idlePhase * 0.6);
        idleHeight = (0.07 + 0.22 * (sm1 * sm2) + 0.07 * sm3) * Math.cos(u * 1.2);
      } else if (style === "wave") {
        // Classic symmetric wave
        var w1 = 0.5 + 0.5 * Math.sin(u * 6.28 - root.idlePhase * 2.2);
        var w2 = 0.5 + 0.5 * Math.cos(u * 12.56 + root.idlePhase * 1.3);
        var wCombined = w1 * 0.7 + w2 * 0.3;
        var pulseB = 0.75 * (0.5 + 0.5 * Math.sin(root.idlePhase * 1.5)) + 0.25 * (0.5 + 0.5 * Math.sin(root.idlePhase * 3.0));
        idleHeight = (0.10 + 0.16 * pulseB + 0.22 * wCombined) * Math.cos(u * 1.25);
      } else {
        // "aurora" (Default): Organic multi-frequency flow (Aurora Borealis) - ultra smooth and elegant
        var a1 = 0.5 + 0.5 * Math.sin(u * 5.2 - root.idlePhase * 1.3);
        var a2 = 0.5 + 0.5 * Math.cos(u * 8.7 + root.idlePhase * 0.85);
        var a3 = 0.5 + 0.5 * Math.sin(u * 13.1 - root.idlePhase * 1.7);
        var aCombined = a1 * 0.50 + a2 * 0.35 + a3 * 0.15;
        var breath = 0.82 + 0.18 * Math.sin(root.idlePhase * 0.7);
        var taper = Math.cos(u * 1.25);
        idleHeight = (0.07 + 0.34 * aCombined * breath) * taper;
      }

      idleHeight = Math.max(0.05, Math.min(0.60, idleHeight));

      if (!root.idleAnimation) {
        idleHeight = 0.0;
      }

      // Blend audio spectrum with idle animation
      var targetVal = (root.activity * rawVal) + ((1.0 - root.activity) * idleHeight);

      // Smooth interpolation for silky motion
      var prevVal = root.currentLevels[i] || 0.0;
      var diff = targetVal - prevVal;
      var smoothK = diff > 0 ? (0.45 + 0.35 * root.activity) : 0.22;
      var curVal = prevVal + diff * smoothK;
      if (Math.abs(curVal - targetVal) < 0.002) curVal = targetVal;

      root.currentLevels[i] = curVal;
      out[i] = curVal;
    }

    root.visualizerValues = out;
  }

  Timer {
    id: animTimer
    interval: Math.max(16, Math.round(1000 / (Settings.data.audio.spectrumFrameRate || 60)))
    running: root.visible && root.shouldShow
    repeat: true
    triggeredOnStart: true
    onTriggered: root.updateVisualizerFrame()
  }

  // Register/unregister with SpectrumService based on configuration
  readonly property string spectrumComponentId: "bar:audiovisualizer:" + screenName + ":" + root.section + ":" + root.sectionWidgetIndex

  onIsVisualizerConfiguredChanged: {
    if (root.isVisualizerConfigured) {
      SpectrumService.registerComponent(root.spectrumComponentId);
    } else {
      SpectrumService.unregisterComponent(root.spectrumComponentId);
    }
  }

  Component.onCompleted: {
    if (root.isVisualizerConfigured) {
      SpectrumService.registerComponent(root.spectrumComponentId);
    }
    root.updateVisualizerFrame();
  }

  Component.onDestruction: {
    SpectrumService.unregisterComponent(root.spectrumComponentId);
  }

  // Content dimensions for implicit sizing and capsule
  readonly property real contentWidth: !shouldShow ? 0 : isVerticalBar ? capsuleHeight : visualizerWidth
  readonly property real contentHeight: !shouldShow ? 0 : isVerticalBar ? visualizerWidth : capsuleHeight

  implicitWidth: !shouldShow ? 0 : isVerticalBar ? capsuleHeight : configuredWidth
  implicitHeight: !shouldShow ? 0 : isVerticalBar ? configuredWidth : capsuleHeight
  width: isGapFillActive ? (root.parent ? root.parent.width : implicitWidth) : implicitWidth
  height: root.parent ? root.parent.height : implicitHeight
  visible: shouldShow
  opacity: shouldShow ? 1.0 : 0.0

  Behavior on implicitWidth {
    enabled: !root.isGapFillActive
    NumberAnimation {
      duration: Style.animationNormal
      easing.type: Easing.InOutCubic
    }
  }
  Behavior on implicitHeight {
    enabled: !root.isGapFillActive
    NumberAnimation {
      duration: Style.animationNormal
      easing.type: Easing.InOutCubic
    }
  }

  // Store visualizer type to force re-evaluation
  readonly property string currentVisualizerType: Settings.data.audio.visualizerType

  // Visual capsule centered in parent
  Rectangle {
    id: background
    width: root.contentWidth
    height: root.contentHeight
    anchors.centerIn: parent
    radius: Style.radiusS
    color: Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    // When visualizer type or playback changes, shouldShow updates automatically
    // The Loader dynamically loads the appropriate visualizer based on settings
    Loader {
      id: visualizerLoader
      anchors.fill: parent
      anchors.topMargin: Style.marginS
      anchors.bottomMargin: Style.marginS
      anchors.leftMargin: root.isGapFillActive ? 0 : Style.marginS
      anchors.rightMargin: root.isGapFillActive ? 0 : Style.marginS
      active: shouldShow
      asynchronous: false

      sourceComponent: {
        switch (currentVisualizerType) {
        case "linear":
          return linearComponent;
        case "mirrored":
          return mirroredComponent;
        case "wave":
          return waveComponent;
        default:
          return null;
        }
      }
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": "Cycle idle animation",
        "action": "cycle-idle-style",
        "icon": "wand-magic-sparkles"
      },
      {
        "label": I18n.tr("actions.cycle-visualizer"),
        "action": "cycle-visualizer",
        "icon": "chart-column"
      },
      {
        "label": I18n.tr("actions.widget-settings"),
        "action": "widget-settings",
        "icon": "settings"
      },
    ]

    onTriggered: action => {
                   contextMenu.close();
                   if (screen) {
                     PanelService.closeContextMenu(screen);
                   }

                   if (action === "cycle-idle-style") {
                     const styles = ["aurora", "pulse", "scanner", "shimmer", "wave"];
                     const curIdx = styles.indexOf(root.idleStyle);
                     const nextIdx = (curIdx + 1) % styles.length;
                     var newStyle = styles[nextIdx];
                     var currentWidgets = Settings.getBarWidgetsForScreen(screenName);
                     if (currentWidgets && currentWidgets[section] && sectionWidgetIndex < currentWidgets[section].length) {
                       currentWidgets[section][sectionWidgetIndex].idleStyle = newStyle;
                       Settings.save();
                     }
                   } else if (action === "cycle-visualizer") {
                     const types = ["linear", "mirrored", "wave"];
                     const currentIndex = types.indexOf(currentVisualizerType);
                     const nextIndex = (currentIndex + 1) % types.length;
                     Settings.data.audio.visualizerType = types[nextIndex];
                   } else if (action === "widget-settings" && screen) {
                     BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
                   }
                 }
  }

  // Click handling:
  // - Left click: cycle visualizer mode (Linear, Mirrored, Wave)
  // - Right click: open Visualizer context menu (cycle animation, visualizer type, widget settings)
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: mouse => {
                 if (mouse.button === Qt.RightButton) {
                   if (screen) {
                     PanelService.showContextMenu(contextMenu, root, screen);
                   }
                 } else {
                   const types = ["linear", "mirrored", "wave"];
                   const currentIndex = types.indexOf(currentVisualizerType);
                   const nextIndex = (currentIndex + 1) % types.length;
                   Settings.data.audio.visualizerType = types[nextIndex];
                 }
               }
  }

  Component {
    id: linearComponent
    NLinearSpectrum {
      anchors.fill: parent
      values: root.visualizerValues
      fillColor: root.fillColor
      showMinimumSignal: false
      vertical: root.isVerticalBar
      barPosition: root.barPosition
      mirrored: Settings.data.audio.spectrumMirrored
    }
  }

  Component {
    id: mirroredComponent
    NMirroredSpectrum {
      anchors.fill: parent
      values: root.visualizerValues
      fillColor: root.fillColor
      showMinimumSignal: false
      vertical: root.isVerticalBar
      mirrored: Settings.data.audio.spectrumMirrored
    }
  }

  Component {
    id: waveComponent
    NWaveSpectrum {
      anchors.fill: parent
      values: root.visualizerValues
      fillColor: root.fillColor
      showMinimumSignal: false
      vertical: root.isVerticalBar
      mirrored: Settings.data.audio.spectrumMirrored
    }
  }
}
