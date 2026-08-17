import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Compositor
import qs.Services.Hardware
import qs.Services.Keyboard
import qs.Services.Location
import qs.Services.Media
import qs.Services.System
import qs.Widgets
import qs.Widgets.AudioSpectrum

Item {
  id: root
  anchors.fill: parent

  required property var lockControl
  required property var batteryIndicator
  required property var keyboardLayout
  required property TextInput passwordInput

  readonly property bool animationsEnabled: Settings.data.general.lockScreenAnimations || false

  // Session timer properties for notification compatibility
  property bool timerActive: false
  property string pendingAction: ""
  property int timeRemaining: 0
  function cancelTimer() { timerActive = false; }

  // Register with SpectrumService for live PipeWire audio visualizer
  readonly property string spectrumComponentId: "lockscreen:audiovisualizer"
  Component.onCompleted: {
    SpectrumService.registerComponent(root.spectrumComponentId);
  }
  Component.onDestruction: {
    SpectrumService.unregisterComponent(root.spectrumComponentId);
  }

  // ─────────────────────────────────────────────────────────────
  // 1. Audio Visualizer (Noctalia Built-in PipeWire Spectrum)
  // ─────────────────────────────────────────────────────────────
  Item {
    id: visualizerContainer
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: passwordBox.top
    anchors.bottomMargin: 10
    width: 550
    height: 28
    visible: MediaService.isPlaying
    opacity: visible ? 1.0 : 0.0

    Behavior on opacity {
      NumberAnimation {
        duration: Style.animationNormal
        easing.type: Easing.OutCubic
      }
    }

    NMirroredSpectrum {
      anchors.fill: parent
      values: SpectrumService.values
      fillColor: Color.mPrimary
      showMinimumSignal: true
      mirrored: true
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Password Input Field (Exact 550 x 55 Omarchy Flat Box)
  // ─────────────────────────────────────────────────────────────
  Rectangle {
    id: passwordBox
    anchors.centerIn: parent
    width: 550
    height: 55
    color: Color.mSurfaceVariant
    radius: 0

    border.color: {
      if (lockControl.showFailure) return Color.mError;
      if (lockControl.unlockInProgress) return Color.mTertiary;
      return Color.mPrimary;
    }
    border.width: 4

    Behavior on border.color {
      ColorAnimation {
        duration: 180
      }
    }

    // Click on box to focus input
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.IBeamCursor
      onClicked: passwordInput.forceActiveFocus()
    }

    // Placeholder text ("Enter Password" or Error text)
    NText {
      anchors.centerIn: parent
      visible: passwordInput.text.length === 0
      text: {
        if (lockControl.showFailure) {
          return "<i>" + (lockControl.errorMessage || "Authentication failed") + "</i>";
        }
        if (lockControl.unlockInProgress) {
          return "<i>Authenticating...</i>";
        }
        return "Enter Password";
      }
      color: lockControl.showFailure ? Color.mError : Qt.alpha(Color.mOnSurface, 0.45)
      pointSize: 13
      font.family: Settings.data.ui.fontDefault || "Sans"
      textFormat: Text.RichText
    }

    // Password Dots (Centered)
    Row {
      anchors.centerIn: parent
      spacing: 12
      visible: passwordInput.text.length > 0

      Repeater {
        model: Math.min(passwordInput.text.length, 32)
        Rectangle {
          width: 9
          height: 9
          radius: width / 2
          color: Color.mOnSurface

          Behavior on scale {
            NumberAnimation {
              duration: 120
              easing.type: Easing.OutBack
            }
          }
        }
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 3. Futuristic Now Playing HUD (Clickable & Themed)
  // ─────────────────────────────────────────────────────────────
  Item {
    id: mediaHUD
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: passwordBox.bottom
    anchors.topMargin: 20
    width: 550
    height: 95
    visible: MediaService.trackTitle !== "" && MediaService.trackTitle !== undefined
    opacity: visible ? 1.0 : 0.0

    Behavior on opacity {
      NumberAnimation {
        duration: Style.animationNormal
        easing.type: Easing.OutCubic
      }
    }

    ColumnLayout {
      anchors.fill: parent
      spacing: 6

      // Line 1: Sci-Fi Header
      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 6

        NText {
          text: "─── ⟨"
          color: Color.mTertiary
          pointSize: 9
          opacity: 0.6
        }

        NIcon {
          icon: MediaService.isPlaying ? "music" : "player-pause"
          pointSize: 10
          color: MediaService.isPlaying ? Color.mPrimary : Color.mOnSurfaceVariant
        }

        NText {
          text: "NOW PLAYING // " + (MediaService.isPlaying ? "STREAMING" : "PAUSED") + " ⟩ ───"
          color: Color.mTertiary
          pointSize: 9
          font.weight: Style.fontWeightBold
          opacity: 0.75
        }
      }

      // Line 2: Track Title & Artist
      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 8

        NText {
          text: MediaService.trackTitle || "Unknown Track"
          color: Color.mOnSurface
          pointSize: 12
          font.weight: Style.fontWeightBold
          elide: Text.ElideRight
          Layout.maximumWidth: 320
        }

        NText {
          text: "◈"
          color: Color.mSecondary
          pointSize: 10
          opacity: 0.7
        }

        NText {
          text: MediaService.trackArtist || "Unknown Artist"
          color: Color.mSecondary
          pointSize: 11
          elide: Text.ElideRight
          Layout.maximumWidth: 200
        }
      }

      // Line 3: Interactive Clickable Controls (Prev / Play-Pause / Next)
      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 12

        // Previous Button
        Rectangle {
          width: 85
          height: 26
          radius: 3
          color: prevMouse.containsMouse ? Qt.alpha(Color.mTertiary, 0.25) : "transparent"
          border.color: Color.mTertiary
          border.width: 1

          RowLayout {
            anchors.centerIn: parent
            spacing: 4
            NIcon { icon: "player-skip-back"; pointSize: 10; color: Color.mTertiary }
            NText { text: "PREV"; pointSize: 9; color: Color.mTertiary; font.weight: Style.fontWeightBold }
          }

          MouseArea {
            id: prevMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: MediaService.previous()
          }
        }

        // Play/Pause Button
        Rectangle {
          width: 95
          height: 26
          radius: 3
          color: playMouse.containsMouse ? Qt.alpha(Color.mPrimary, 0.3) : Qt.alpha(Color.mPrimary, 0.12)
          border.color: Color.mPrimary
          border.width: 1

          RowLayout {
            anchors.centerIn: parent
            spacing: 4
            NIcon {
              icon: MediaService.isPlaying ? "player-pause" : "player-play"
              pointSize: 10
              color: Color.mPrimary
            }
            NText {
              text: MediaService.isPlaying ? "PAUSE" : "PLAY"
              pointSize: 9
              color: Color.mPrimary
              font.weight: Style.fontWeightBold
            }
          }

          MouseArea {
            id: playMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: MediaService.playPause()
          }
        }

        // Next Button
        Rectangle {
          width: 85
          height: 26
          radius: 3
          color: nextMouse.containsMouse ? Qt.alpha(Color.mTertiary, 0.25) : "transparent"
          border.color: Color.mTertiary
          border.width: 1

          RowLayout {
            anchors.centerIn: parent
            spacing: 4
            NText { text: "NEXT"; pointSize: 9; color: Color.mTertiary; font.weight: Style.fontWeightBold }
            NIcon { icon: "player-skip-forward"; pointSize: 10; color: Color.mTertiary }
          }

          MouseArea {
            id: nextMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: MediaService.next()
          }
        }
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 4. System Info Line (Bottom Center)
  // ─────────────────────────────────────────────────────────────
  RowLayout {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 35
    spacing: 16

    NText {
      text: "HOST: " + (SystemService.data.hostname || "Linux") + "  //  UPTIME: " + (SystemService.data.uptime || "Online")
      color: Color.mOnSurfaceVariant
      pointSize: 10
      font.family: Settings.data.ui.fontDefault || "Sans"
      opacity: 0.75
    }
  }
}
