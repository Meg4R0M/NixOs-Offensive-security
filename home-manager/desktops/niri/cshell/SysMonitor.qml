// Humanix — moniteur système, remplace le lecteur de musique dans le DashBoard.
// Réutilise le service System (cpuUsage/memoryUsage = fraction 0..1, wifi, batterie).
// Géométrie alignée sur l'ancien MusicPlayer (colonne de droite, largeur 300) pour
// que les ancrages `player.left` du DashBoard restent valides.
import QtQuick
import qs.services
import qs.components

Rectangle {
  id: root
  anchors.right: parent.right
  anchors.top: parent.top
  anchors.bottom: parent.bottom
  anchors.topMargin: 80
  anchors.leftMargin: 10
  width: 300
  radius: 20
  color: "#0a0f0a"

  Column {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: 28
    anchors.rightMargin: 28
    spacing: 18

    StyledText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "// SYSTEM"
      font.pointSize: 20
      color: "#00ff41"
    }

    // ---- CPU ----
    Item {
      width: parent.width
      height: cpuL.height
      StyledText { id: cpuL; anchors.left: parent.left; text: "CPU"; color: "#00cc33"; font.pointSize: 14 }
      StyledText { anchors.right: parent.right; text: Math.round(System.cpuUsage * 100) + "%"; font.pointSize: 14 }
    }
    Rectangle {
      width: parent.width; height: 8; radius: 4; color: "#123312"
      Rectangle {
        height: parent.height; radius: 4; color: "#00ff41"
        width: parent.width * Math.max(0, Math.min(1, System.cpuUsage))
      }
    }

    // ---- MEM ----
    Item {
      width: parent.width
      height: memL.height
      StyledText { id: memL; anchors.left: parent.left; text: "MEM"; color: "#00cc33"; font.pointSize: 14 }
      StyledText { anchors.right: parent.right; text: Math.round(System.memoryUsage * 100) + "%"; font.pointSize: 14 }
    }
    Rectangle {
      width: parent.width; height: 8; radius: 4; color: "#123312"
      Rectangle {
        height: parent.height; radius: 4; color: "#00ff41"
        width: parent.width * Math.max(0, Math.min(1, System.memoryUsage))
      }
    }

    // ---- NET (wifi) ----
    Item {
      width: parent.width
      height: netL.height
      StyledText { id: netL; anchors.left: parent.left; text: "NET"; color: "#00cc33"; font.pointSize: 14 }
      StyledText {
        anchors.right: parent.right
        text: System.wifiConnected ? System.get_current_wifi_name() : "offline"
        color: System.wifiConnected ? "#00ff41" : "#ff2b2b"
        font.pointSize: 14
      }
    }

    // ---- BAT ----
    Item {
      width: parent.width
      height: batL.height
      StyledText { id: batL; anchors.left: parent.left; text: "BAT"; color: "#00cc33"; font.pointSize: 14 }
      StyledText {
        anchors.right: parent.right
        text: System.batteryIcon + "  " + System.batteryPercent + "%"
        color: (System.batteryPercent < 25 && !System.charging) ? "#ff2b2b" : "#00ff41"
        font.pointSize: 14
      }
    }
  }
}
