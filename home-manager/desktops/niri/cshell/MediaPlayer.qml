// Humanix — Lecteur média (MPRIS) pour cshell, rendu dans le BotLeftPopup.
import QtQuick
import qs.services
import qs.components

Item {
  id: root
  anchors.fill: parent
  anchors.margins: 22
  opacity: parent.width >= 250 ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: 200 } }

  property var music: System.get_player()

  Column {
    anchors.centerIn: parent
    width: parent.width
    spacing: 12

    StyledText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "// MEDIA"; font.pointSize: 18; color: "#00ff41"
    }
    StyledText {
      width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
      text: root.music ? (root.music.trackTitle || "—") : "No media"
      font.pointSize: 15; color: "#00ff41"
    }
    StyledText {
      width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
      text: root.music ? (root.music.trackArtist || "") : ""
      font.pointSize: 12; color: "#1f8f3f"
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 18
      topPadding: 6

      component Ctl: Rectangle {
        id: ctl
        property string glyph
        signal act()
        width: 54; height: 54; radius: 27; color: "#123312"
        Icon { anchors.centerIn: parent; icon: ctl.glyph; textSize: 22; color: "#00ff41" }
        MouseArea { anchors.fill: parent; onClicked: ctl.act() }
      }

      Ctl { glyph: "󰒮"; onAct: if (root.music) root.music.previous() }
      Ctl {
        glyph: root.music && root.music.isPlaying ? "󰏤" : "󰐊"
        onAct: if (root.music) root.music.togglePlaying()
      }
      Ctl { glyph: "󰒭"; onAct: if (root.music) root.music.next() }
    }
  }
}
