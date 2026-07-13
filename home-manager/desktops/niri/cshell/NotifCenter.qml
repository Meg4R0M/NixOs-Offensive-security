// Humanix — Centre de notifications (historique) pour cshell. Lit NotifStore.
import QtQuick
import qs.popups
import qs.components

Item {
  id: root
  anchors.fill: parent
  anchors.margins: 18
  opacity: parent.width >= 300 ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: 200 } }

  Column {
    anchors.fill: parent
    spacing: 10

    Item {
      width: parent.width
      height: title.height
      StyledText {
        id: title
        anchors.left: parent.left
        text: "// NOTIFICATIONS"; font.pointSize: 18; color: "#00ff41"
      }
      Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: title.verticalCenter
        width: 62; height: 26; radius: 8; color: "#123312"
        StyledText { anchors.centerIn: parent; text: "clear"; font.pointSize: 10; color: "#ff2b2b" }
        MouseArea { anchors.fill: parent; onClicked: NotifStore.clearAll() }
      }
    }

    StyledText {
      visible: NotifStore.model.count === 0
      anchors.horizontalCenter: parent.horizontalCenter
      text: "— aucune notification —"; font.pointSize: 12; color: "#1f8f3f"
      topPadding: 40
    }

    ListView {
      width: parent.width
      height: parent.height - 44
      clip: true
      spacing: 8
      model: NotifStore.model

      delegate: Rectangle {
        required property string summary
        required property string body
        required property string app
        width: ListView.view.width
        implicitHeight: col.implicitHeight + 18
        radius: 12
        color: "#0a0f0a"
        border.width: 1; border.color: "#1f4d1f"

        Column {
          id: col
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.margins: 10
          spacing: 3

          Row {
            width: parent.width
            spacing: 8
            StyledText { text: summary; font.pointSize: 12; color: "#00ff41"; elide: Text.ElideRight }
            StyledText { text: app; font.pointSize: 10; color: "#1f8f3f" }
          }
          StyledText {
            width: parent.width
            visible: body.length > 0
            text: body; font.pointSize: 11; color: "#00cc33"
            wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
          }
        }
      }
    }
  }
}
