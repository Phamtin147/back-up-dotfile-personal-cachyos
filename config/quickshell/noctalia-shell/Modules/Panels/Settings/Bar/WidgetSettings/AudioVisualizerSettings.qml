import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  // Properties to receive data from parent
  property var screen: null
  property var widgetData: null
  property var widgetMetadata: null

  signal settingsChanged(var settings)

  // Local state
  property bool valueHideWhenIdle: widgetData.hideWhenIdle !== undefined ? widgetData.hideWhenIdle : widgetMetadata.hideWhenIdle
  property string valueColorName: widgetData.colorName !== undefined ? widgetData.colorName : widgetMetadata.colorName
  property bool valueIdleAnimation: widgetData.idleAnimation !== undefined ? widgetData.idleAnimation : true
  property string valueIdleStyle: widgetData.idleStyle !== undefined ? widgetData.idleStyle : (widgetMetadata.idleStyle || "aurora")
  property bool valueFillGap: widgetData.fillGap !== undefined ? widgetData.fillGap : true

  function saveSettings() {
    var settings = Object.assign({}, widgetData || {});
    settings.width = parseInt(widthInput.text) || widgetMetadata.width;
    settings.hideWhenIdle = valueHideWhenIdle;
    settings.colorName = valueColorName;
    settings.idleAnimation = valueIdleAnimation;
    settings.idleStyle = valueIdleStyle;
    settings.fillGap = valueFillGap;
    settingsChanged(settings);
    return settings;
  }

  NTextInput {
    id: widthInput
    Layout.fillWidth: true
    label: I18n.tr("common.width")
    description: I18n.tr("bar.audio-visualizer.width-description")
    text: widgetData.width || widgetMetadata.width
    placeholderText: I18n.tr("placeholders.enter-width-pixels")
    onTextChanged: saveSettings()
    defaultValue: String(widgetMetadata.width)
  }

  NColorChoice {
    Layout.fillWidth: true
    label: I18n.tr("bar.audio-visualizer.color-name-label")
    description: I18n.tr("bar.audio-visualizer.color-name-description")
    currentKey: root.valueColorName
    onSelected: key => {
                  root.valueColorName = key;
                  saveSettings();
                }
    defaultValue: widgetMetadata.colorName
  }

  NToggle {
    label: I18n.tr("bar.audio-visualizer.hide-when-idle-label")
    description: I18n.tr("bar.audio-visualizer.hide-when-idle-description")
    checked: valueHideWhenIdle
    onToggled: checked => {
                 valueHideWhenIdle = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.hideWhenIdle
  }

  NToggle {
    label: "Idle wave animation"
    description: "Display smooth sine wave animation when no audio is playing"
    checked: valueIdleAnimation
    onToggled: checked => {
                 valueIdleAnimation = checked;
                 saveSettings();
               }
    defaultValue: true
  }

  NComboBox {
    Layout.fillWidth: true
    label: "Idle animation style"
    description: "Visual animation pattern when no audio is playing"
    visible: root.valueIdleAnimation
    model: [
      {
        "key": "aurora",
        "name": "Aurora Flow (Cực quang hữu cơ mềm mại)"
      },
      {
        "key": "pulse",
        "name": "Breathing Heartbeat (Nhịp thở Ryoku Pulse)"
      },
      {
        "key": "scanner",
        "name": "Cyberpunk Scanner (Tia quét Radar)"
      },
      {
        "key": "shimmer",
        "name": "Lo-fi Shimmer (Lấp lánh tinh tú)"
      },
      {
        "key": "wave",
        "name": "Classic Symmetrical Wave (Sóng sin đối xứng)"
      }
    ]
    currentKey: root.valueIdleStyle
    onSelected: key => {
                  root.valueIdleStyle = key;
                  saveSettings();
                }
    defaultValue: "aurora"
  }

  NToggle {
    label: "Fill bar gap"
    description: "Expand to fill the entire gap between left and right bar modules"
    checked: valueFillGap
    onToggled: checked => {
                 valueFillGap = checked;
                 saveSettings();
               }
    defaultValue: true
  }
}
