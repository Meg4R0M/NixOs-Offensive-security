// Humanix — Launcher d'apps (fenêtre focusable) pour cshell. Fuzzy simple sur
// DesktopEntries ; Entrée/clic => .execute(). Ouvert via GlobalStates.launcherOpen
// (clic sur le logo de la barre). Fenêtre séparée => une panne reste isolée.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.popups
import qs.components

PanelWindow {
  id: win
  visible: GlobalStates.launcherOpen
  color: "transparent"

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  property string query: ""
  property var apps: {
    const all = DesktopEntries.applications.values.filter(a => a && !a.noDisplay)
    const q = win.query.trim().toLowerCase()
    const list = (q.length === 0)
      ? all
      : all.filter(a => (a.name || "").toLowerCase().includes(q))
    return list.slice(0, 50)
  }

  function close() {
    GlobalStates.launcherOpen = false
    win.query = ""
    input.text = ""
  }

  // Fond assombri, clic hors boîte => ferme.
  Rectangle {
    anchors.fill: parent
    color: "#cc000000"
    MouseArea { anchors.fill: parent; onClicked: win.close() }
  }

  Rectangle {
    id: box
    anchors.centerIn: parent
    width: 640
    height: 540
    radius: 24
    color: "#0a0f0a"
    border.width: 2
    border.color: "#1f4d1f"

    Column {
      anchors.fill: parent
      anchors.margins: 20
      spacing: 14

      Rectangle {
        width: parent.width
        height: 50
        radius: 12
        color: "#123312"

        TextInput {
          id: input
          anchors.fill: parent
          anchors.leftMargin: 14
          anchors.rightMargin: 14
          verticalAlignment: Text.AlignVCenter
          font.family: "JetBrainsMono NerdFont"
          font.pixelSize: 18
          color: "#00ff41"
          clip: true
          focus: true
          onTextChanged: win.query = text
          Keys.onEscapePressed: win.close()
          Keys.onReturnPressed: {
            if (win.apps.length > 0) {
              win.apps[0].execute()
              win.close()
            }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0
            text: "Rechercher une app…"
            color: "#1f6d2f"
            font: input.font
          }
        }
      }

      ListView {
        width: parent.width
        height: parent.height - 64
        clip: true
        model: win.apps
        spacing: 4

        delegate: Rectangle {
          required property var modelData
          width: ListView.view.width
          height: 46
          radius: 10
          color: lma.containsMouse ? "#123312" : "transparent"

          StyledText {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 16
            text: modelData ? (modelData.name || "?") : "?"
            font.pointSize: 13
            color: "#00ff41"
          }
          MouseArea {
            id: lma
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
              if (modelData) modelData.execute()
              win.close()
            }
          }
        }
      }
    }
  }

  onVisibleChanged: {
    if (visible) input.forceActiveFocus()
  }
}
