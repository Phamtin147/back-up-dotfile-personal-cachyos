import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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

  readonly property bool animationsEnabled: Settings.data.general.lockScreenAnimations !== undefined ? Settings.data.general.lockScreenAnimations : true

  // Notification properties compatibility
  property bool timerActive: false
  property string pendingAction: ""
  property int timeRemaining: 0
  function cancelTimer() { timerActive = false; }

  // Register with SpectrumService for live PipeWire audio visualizer
  readonly property string spectrumComponentId: "lockscreen:audiovisualizer"
  Component.onCompleted: {
    SpectrumService.registerComponent(root.spectrumComponentId);
    systemInfoProcess.running = true;
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
    anchors.bottom: passwordInputContainer.top
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
  // 2. Password Input Field (Noctalia Full Input Engine + 550x55 Style)
  // ─────────────────────────────────────────────────────────────
  Rectangle {
    id: passwordInputContainer
    anchors.centerIn: parent
    width: 550
    height: 55
    radius: 0
    color: Color.mSurfaceVariant

    border.color: {
      if (lockControl && lockControl.showFailure) return Color.mError;
      if (lockControl && lockControl.unlockInProgress) return Color.mTertiary;
      return passwordInput.activeFocus ? Color.mPrimary : Qt.alpha(Color.mOutline, 0.4);
    }
    border.width: 4

    property bool passwordVisible: false

    Behavior on border.color {
      ColorAnimation { duration: 180 }
    }

    // Shortcut: Ctrl + A to select all
    Shortcut {
      sequence: StandardKey.SelectAll
      enabled: passwordInput.activeFocus
      onActivated: passwordInput.selectAll()
    }

    // Shortcut: Esc to deselect
    Shortcut {
      sequences: [StandardKey.Cancel]
      enabled: passwordInput.activeFocus && passwordInput.selectionStart !== passwordInput.selectionEnd
      onActivated: passwordInput.deselect()
    }

    Row {
      anchors.left: parent.left
      anchors.leftMargin: 18
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.marginL

      // Lock / Login Icon
      NIcon {
        icon: "login-2"
        pointSize: Style.fontSizeL
        color: passwordInput.activeFocus ? Color.mPrimary : Color.mOnSurfaceVariant
        anchors.verticalCenter: parent.verticalCenter
      }

      Row {
        spacing: 0
        anchors.verticalCenter: parent.verticalCenter

        // Blinking Caret when empty
        Rectangle {
          width: 2
          height: 22
          color: Color.mPrimary
          visible: passwordInput.activeFocus && passwordInput.text.length === 0
          anchors.verticalCenter: parent.verticalCenter

          SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: root.animationsEnabled && passwordInput.activeFocus && passwordInput.text.length === 0
            NumberAnimation { to: 0; duration: 530 }
            NumberAnimation { to: 1; duration: 530 }
          }
        }

        // Placeholder Text when empty
        NText {
          text: (lockControl && lockControl.showFailure) ? (lockControl.errorMessage || "Authentication failed") : "Enter Password"
          color: (lockControl && lockControl.showFailure) ? Color.mError : Qt.alpha(Color.mOnSurface, 0.45)
          pointSize: 13
          font.family: Settings.data.ui.fontDefault || "Sans"
          visible: passwordInput.text.length === 0
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: 4
        }

        // Password Visual Host (Dots / Plain Text)
        Item {
          id: passwordVisualHost
          height: 22
          width: passwordInputContainer.passwordVisible ? Math.min(visiblePasswordPlainText.implicitWidth, 400) : Math.min(passwordDisplayContent.width, 400)
          anchors.verticalCenter: parent.verticalCenter

          readonly property real caretVisualX: {
            const len = passwordInput.text.length;
            if (len <= 0) return 0;
            if (passwordInputContainer.passwordVisible) {
              const adv = passwordCaretFontMetrics.advanceWidth(passwordInput.text.substring(0, passwordInput.cursorPosition));
              return Math.max(0, Math.min(adv, width));
            }
            const w = passwordDisplayContent.width;
            if (w <= 0) return 0;
            return Math.max(0, Math.min((passwordInput.cursorPosition / len) * w, width));
          }

          // Animated Password Dots
          Item {
            width: Math.min(passwordDisplayContent.width, 400)
            height: 22
            visible: passwordInput.text.length > 0 && !passwordInputContainer.passwordVisible
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            // Selection highlight
            Rectangle {
              id: selectionHighlight
              visible: passwordInput.selectionStart !== passwordInput.selectionEnd && passwordInput.text.length > 0
              color: Qt.alpha(Color.mPrimary, 0.8)
              height: parent.height
              anchors.verticalCenter: parent.verticalCenter
              x: (passwordInput.selectionStart / passwordInput.text.length) * passwordDisplayContent.width
              width: ((passwordInput.selectionEnd - passwordInput.selectionStart) / passwordInput.text.length) * passwordDisplayContent.width
            }

            Row {
              id: passwordDisplayContent
              spacing: 6
              anchors.verticalCenter: parent.verticalCenter

              Repeater {
                id: iconRepeater
                model: ScriptModel {
                  values: Array(passwordInput.text.length)
                }

                readonly property var passwordChars: ["circle-filled", "pentagon-filled", "michelin-star-filled", "square-rounded-filled", "guitar-pick-filled", "blob-filled", "triangle-filled"]

                NIcon {
                  id: icon
                  required property int index
                  property bool isSelected: index >= 0 && passwordInput.selectionStart !== passwordInput.selectionEnd && index >= passwordInput.selectionStart && index < passwordInput.selectionEnd

                  icon: iconRepeater.passwordChars[index % iconRepeater.passwordChars.length]
                  pointSize: Style.fontSizeL
                  color: isSelected ? Color.mOnPrimary : Color.mPrimary
                  opacity: 1.0
                  scale: animationsEnabled ? 0.5 : 1

                  ParallelAnimation {
                    id: iconAnim
                    NumberAnimation {
                      target: icon
                      properties: "scale"
                      to: 1
                      duration: Style.animationFast
                      easing.type: Easing.OutBack
                    }
                  }

                  Component.onCompleted: {
                    if (animationsEnabled) iconAnim.start();
                  }
                }
              }
            }

            // Mouse Area for drag & select
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.IBeamCursor
              onPressed: function(mouse) {
                passwordInput.forceActiveFocus();
                var charWidth = passwordDisplayContent.width / Math.max(1, passwordInput.text.length);
                passwordInput.cursorPosition = Math.max(0, Math.min(passwordInput.text.length, Math.floor(mouse.x / charWidth)));
              }
            }
          }

          // Plain text when eye toggle is ON
          NText {
            id: visiblePasswordPlainText
            text: passwordInput.text
            color: Color.mPrimary
            pointSize: Style.fontSizeM
            visible: passwordInput.text.length > 0 && passwordInputContainer.passwordVisible
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 400)
          }

          FontMetrics {
            id: passwordCaretFontMetrics
            font: visiblePasswordPlainText.font
          }

          // Blinking Caret while typing
          Rectangle {
            width: 2
            height: 22
            x: passwordVisualHost.caretVisualX
            color: Color.mPrimary
            visible: passwordInput.activeFocus && passwordInput.text.length > 0 && passwordInput.selectionStart === passwordInput.selectionEnd
            anchors.verticalCenter: parent.verticalCenter

            SequentialAnimation on opacity {
              loops: Animation.Infinite
              running: root.animationsEnabled && passwordInput.activeFocus && passwordInput.text.length > 0 && passwordInput.selectionStart === passwordInput.selectionEnd
              NumberAnimation { to: 0; duration: 530 }
              NumberAnimation { to: 1; duration: 530 }
            }
          }
        }
      }
    }

    // Right Action Buttons Row (Caps lock + Clear + Eye + Submit)
    RowLayout {
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6

      // Caps Lock Warning Icon
      NIcon {
        icon: "lock"
        pointSize: Style.fontSizeM
        color: Color.mPrimary
        visible: LockKeysService.capsLockOn
      }

      // Clear Button
      Rectangle {
        width: 32
        height: 32
        radius: width / 2
        color: clearMouse.containsMouse ? Qt.alpha(Color.mPrimary, 0.2) : "transparent"
        visible: passwordInput.text.length > 0

        NIcon {
          anchors.centerIn: parent
          icon: "x"
          pointSize: Style.fontSizeM
          color: Color.mOnSurfaceVariant
        }

        MouseArea {
          id: clearMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            passwordInput.text = "";
            passwordInput.forceActiveFocus();
          }
        }
      }

      // Eye Visibility Toggle Button
      Rectangle {
        width: 32
        height: 32
        radius: width / 2
        color: eyeMouse.containsMouse ? Qt.alpha(Color.mPrimary, 0.2) : "transparent"
        visible: passwordInput.text.length > 0

        NIcon {
          anchors.centerIn: parent
          icon: passwordInputContainer.passwordVisible ? "eye-off" : "eye"
          pointSize: Style.fontSizeM
          color: Color.mOnSurfaceVariant
        }

        MouseArea {
          id: eyeMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: passwordInputContainer.passwordVisible = !passwordInputContainer.passwordVisible
        }
      }

      // Submit Arrow Button
      Rectangle {
        width: 36
        height: 36
        radius: 4
        color: submitMouse.containsMouse ? Color.mPrimary : Qt.alpha(Color.mPrimary, 0.2)

        NIcon {
          anchors.centerIn: parent
          icon: "arrow-right"
          pointSize: Style.fontSizeM
          color: submitMouse.containsMouse ? Color.mOnPrimary : Color.mPrimary
        }

        MouseArea {
          id: submitMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (lockControl) lockControl.tryUnlock();
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
    anchors.top: passwordInputContainer.bottom
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
  // 4. Exact Hyprlock System Info Line (Bottom Center)
  // ─────────────────────────────────────────────────────────────
  property string systemInfoOutput: ""

  function formatSystemInfo(raw) {
    if (!raw || raw.trim().length === 0) {
      return "<span style='opacity:0.56;'>User: </span><b>" + SystemService.data.username + "</b>   <span style='opacity:0.56;'>Host: </span><b>" + SystemService.data.hostname + "</b>   <span style='opacity:0.56;'>OS: </span><b>CachyOS</b>   <span style='opacity:0.56;'>Uptime: </span><b>" + SystemService.data.uptime + "</b>";
    }
    let formatted = raw
      .replace(/<span alpha="(\d+)%">/g, (match, p1) => {
        let op = (parseInt(p1) / 100).toFixed(2);
        return `<span style="opacity: ${op};">`;
      })
      .replace(/<span weight="bold" alpha="(\d+)%">/g, (match, p1) => {
        let op = (parseInt(p1) / 100).toFixed(2);
        return `<b style="opacity: ${op};">`;
      });
    return formatted;
  }

  Process {
    id: systemInfoProcess
    command: ["/home/amtia/.local/bin/hyprlock-system-info"]
    stdout: SplitParser {
      onRead: data => {
        if (data && data.trim().length > 0) {
          root.systemInfoOutput = data.trim();
        }
      }
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: systemInfoProcess.running = true
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 50
    text: formatSystemInfo(root.systemInfoOutput)
    textFormat: Text.RichText
    font.pixelSize: 13
    font.family: Settings.data.ui.fontDefault || "Sans"
    color: Color.mOnSurface
  }
}
