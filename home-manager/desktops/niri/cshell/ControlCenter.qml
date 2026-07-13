// Humanix — Control center (réglages rapides) pour cshell, inspiré end-4.
// Rendu dans le BotLeftPopup (comme le menu power). Tout en vert.
//  - toggles wifi (nmcli) / bluetooth (rfkill)
//  - sliders volume (Pipewire, writable) + luminosité (brightnessctl)
//  - profils énergie (PowerProfiles via System.set_power_profile)
// Les @outils@ sont substitués en chemins /nix/store au build (postPatch).
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.services
import qs.components

Item {
  id: root
  anchors.fill: parent
  anchors.margins: 22
  opacity: parent.width >= 300 ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: 200 } }

  Process { id: wifiProc }
  Process { id: btProc }
  Process { id: brtProc }

  ColumnLayout {
    anchors.fill: parent
    spacing: 16

    StyledText {
      text: "// CONTROL"
      font.pointSize: 18
      color: "#00ff41"
      Layout.alignment: Qt.AlignHCenter
    }

    // ---------- Toggles wifi / bluetooth ----------
    RowLayout {
      Layout.fillWidth: true
      spacing: 12

      component Tile: Rectangle {
        id: tile
        property string glyph
        property string label
        property bool on: false
        signal toggled()
        Layout.fillWidth: true
        implicitHeight: 72
        radius: 16
        color: on ? "#123312" : "#0a0f0a"
        border.width: 2
        border.color: on ? "#00ff41" : "#1f4d1f"
        Column {
          anchors.centerIn: parent
          spacing: 5
          Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: tile.glyph; textSize: 26
            color: tile.on ? "#00ff41" : "#1f8f3f"
          }
          StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.label; font.pointSize: 11
            color: tile.on ? "#00ff41" : "#1f8f3f"
            elide: Text.ElideRight
          }
        }
        MouseArea { anchors.fill: parent; onClicked: tile.toggled() }
      }

      Tile {
        glyph: System.wifiIcon
        label: System.wifiOn ? (System.wifiConnected ? System.get_current_wifi_name() : "Wifi") : "Wifi Off"
        on: System.wifiOn
        onToggled: { wifiProc.command = ["@nmcli@", "radio", "wifi", System.wifiOn ? "off" : "on"]; wifiProc.running = true }
      }
      Tile {
        glyph: System.btIcon
        label: System.btOn ? "Bluetooth" : "BT Off"
        on: System.btOn
        onToggled: { btProc.command = ["@rfkill@", System.btOn ? "block" : "unblock", "bluetooth"]; btProc.running = true }
      }
    }

    // ---------- Sliders volume / luminosité ----------
    component SliderRow: RowLayout {
      id: sr
      property string label
      property real value: 0
      signal moved(real v)
      Layout.fillWidth: true
      spacing: 12
      StyledText { text: sr.label; font.pointSize: 12; color: "#00cc33"; Layout.preferredWidth: 42 }
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 14
        radius: 7
        color: "#123312"
        Rectangle {
          height: parent.height; radius: 7; color: "#00ff41"
          width: parent.width * Math.max(0, Math.min(1, sr.value))
        }
        MouseArea {
          anchors.fill: parent
          onPressed: (m) => sr.moved(Math.max(0, Math.min(1, m.x / width)))
          onPositionChanged: (m) => { if (pressed) sr.moved(Math.max(0, Math.min(1, m.x / width))) }
        }
      }
    }

    SliderRow {
      label: System.muted ? "MUTE" : "VOL"
      value: System.volume >= 1 ? 1 : System.volume
      onMoved: (v) => { if (System.sink && System.sink.audio) System.sink.audio.volume = v }
    }
    SliderRow {
      label: "LUM"
      value: System.brightnessPercent / 100
      onMoved: (v) => { brtProc.command = ["@brightnessctl@", "set", Math.round(v * 100) + "%"]; brtProc.running = true }
    }

    // ---------- Profils énergie ----------
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      component Pill: Rectangle {
        id: pill
        property string label
        property bool active: false
        signal picked()
        Layout.fillWidth: true
        implicitHeight: 34
        radius: 12
        color: active ? "#00ff41" : "#123312"
        StyledText {
          anchors.centerIn: parent
          text: pill.label; font.pointSize: 10
          color: pill.active ? "#0a0f0a" : "#00cc33"
        }
        MouseArea { anchors.fill: parent; onClicked: pill.picked() }
      }

      Pill { label: "Saver";    active: System.isPowerSaver;  onPicked: System.set_power_profile(1) }
      Pill { label: "Balanced"; active: System.isBalanced;    onPicked: System.set_power_profile(2) }
      Pill { label: "Perf";     active: System.isPerformance; onPicked: System.set_power_profile(3) }
    }
  }
}
