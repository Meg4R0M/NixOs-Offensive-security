// Humanix — Historique du presse-papier (cliphist) pour cshell.
// Liste via `cliphist list` ; clic => `cliphist decode | wl-copy`.
// @cliphist@ / @wlcopy@ substitués en /nix/store au build.
import QtQuick
import Quickshell.Io
import qs.popups
import qs.components

Item {
  id: root
  anchors.fill: parent
  anchors.margins: 18
  opacity: parent.width >= 300 ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: 200 } }

  ListModel { id: clips }

  Process {
    id: lister
    command: ["@cliphist@", "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        clips.clear()
        const lines = this.text.split("\n")
        for (let i = 0; i < lines.length; i++) {
          if (lines[i].trim().length > 0) clips.append({ entry: lines[i] })
        }
      }
    }
  }
  Process { id: copier }
  Component.onCompleted: lister.running = true

  Column {
    anchors.fill: parent
    spacing: 10

    StyledText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "// CLIPBOARD"; font.pointSize: 18; color: "#00ff41"
    }

    ListView {
      width: parent.width
      height: parent.height - 44
      clip: true
      model: clips
      spacing: 6

      delegate: Rectangle {
        required property string entry
        width: ListView.view.width
        height: 42
        radius: 10
        // PAS de hoverEnabled : dans le BotLeftPopup (onExited: hideBL), une
        // MouseArea enfant hoverEnabled vole le survol -> le popup se ferme avant
        // le clic. Feedback via `pressed` (ne vole pas le survol).
        color: dma.pressed ? "#1f4d1f" : "#0a0f0a"
        border.width: 1; border.color: "#1f4d1f"

        StyledText {
          anchors.fill: parent; anchors.margins: 9
          verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
          text: entry.replace(/^\s*[0-9]+\s+/, "")
          font.pointSize: 11; color: "#00ff41"
        }
        MouseArea {
          id: dma
          anchors.fill: parent
          onClicked: {
            copier.command = ["sh", "-c", "printf '%s' \"$1\" | @cliphist@ decode | @wlcopy@", "cliphist-copy", entry]
            copier.running = true
            PopupComm.hideBL()
          }
        }
      }
    }
  }
}
