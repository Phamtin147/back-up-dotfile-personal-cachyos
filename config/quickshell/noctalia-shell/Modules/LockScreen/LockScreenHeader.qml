import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Hardware
import qs.Services.Keyboard
import qs.Services.System
import qs.Widgets

// Top Bar (52px full width) - Hyprlock Omarchy exact top bar layout synced with Noctalia
Rectangle {
  id: root

  property var batteryIndicator: null

  // Timer-driven clock (updates once a second)
  property date currentTime: new Date()
  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.currentTime = new Date()
  }

  anchors.top: parent.top
  anchors.left: parent.left
  anchors.right: parent.right
  height: 52
  color: Color.mSurface
  border.color: "transparent"
  border.width: 0
  radius: 0
  z: 10

  // 1. Center Clock (Format: hh:mm)
  NText {
    anchors.centerIn: parent
    text: Qt.formatDateTime(root.currentTime, "hh:mm")
    color: Color.mOnSurface
    pointSize: 18
    font.family: Settings.data.ui.fontDefault || "Sans"
    font.weight: Style.fontWeightMedium
  }

  // 2. Right portion: Battery indicator & status
  RowLayout {
    anchors.right: parent.right
    anchors.rightMargin: 32
    anchors.verticalCenter: parent.verticalCenter
    spacing: 8

    NIcon {
      icon: BatteryService.batteryIcon || "battery"
      pointSize: Style.fontSizeL
      color: BatteryService.batteryCharging ? Color.mPrimary : Color.mOnSurface
      visible: BatteryService.batteryReady
    }

    NText {
      text: Math.round(BatteryService.batteryPercentage) + "%"
      color: Color.mOnSurface
      pointSize: 15
      font.family: Settings.data.ui.fontDefault || "Sans"
      visible: BatteryService.batteryReady
    }
  }

  // 3. Left portion: Hostname or user title
  RowLayout {
    anchors.left: parent.left
    anchors.leftMargin: 32
    anchors.verticalCenter: parent.verticalCenter
    spacing: 8

    NIcon {
      icon: "lock"
      pointSize: Style.fontSizeM
      color: Color.mPrimary
    }

    NText {
      text: SystemService.data.username || "LOCKED"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeM
      font.family: Settings.data.ui.fontDefault || "Sans"
      font.capitalization: Font.AllUppercase
    }
  }
}
