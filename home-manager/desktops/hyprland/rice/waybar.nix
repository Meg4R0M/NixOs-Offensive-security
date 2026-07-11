{ config, lib, pkgs, osConfig, ... }:
# Waybar themée Stylix, inspirée de Nix-Relic (layout pills, gradient
# workspaces). Commandes standard (pas la suite de scripts maison relic-cli).
let
  c = config.lib.stylix.colors or null;
  hx = if c != null then builtins.mapAttrs (_: v: "#${v}") c else null;
  # Barre du haut : police Zekton (déposée par l'utilisateur).
  fontName = "Zekton";

  # Petit menu power via rofi (rofi est themé Stylix).
  powerMenu = pkgs.writeShellScript "rice-powermenu" ''
    chosen=$(printf " Lock\n Logout\n Suspend\n Reboot\n Shutdown" | ${pkgs.rofi}/bin/rofi -dmenu -i -p "Power")
    case "$chosen" in
      *Lock)     loginctl lock-session ;;
      *Logout)   hyprctl dispatch exit ;;
      *Suspend)  systemctl suspend ;;
      *Reboot)   systemctl reboot ;;
      *Shutdown) systemctl poweroff ;;
    esac
  '';
in
lib.mkIf (osConfig.athena.useStylix or false) {
  programs.waybar = {
    enable = true;
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 30;
      spacing = 4;
      modules-left = [ "hyprland/workspaces" "hyprland/window" ];
      modules-center = [ "clock" ];
      modules-right = [
        "cpu" "temperature" "memory" "battery"
        "pulseaudio" "network" "bluetooth" "tray" "custom/power"
      ];

      "hyprland/workspaces" = {
        all-outputs = true;
        on-click = "activate";
        format = "{icon}";
      };
      "hyprland/window" = {
        format = " 󱄅 {}";
        separate-outputs = true;
        max-length = 50;
      };
      clock = {
        format = "󰥔  {:%H:%M}";
        format-alt = "{:%Y-%m-%d  %H:%M}";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      };
      cpu = { interval = 5; format = "󰍛 {usage}%"; };
      temperature = {
        critical-threshold = 85;
        format = "{icon} {temperatureC}°C";
        format-icons = [ "" "" "" "" "" ];
      };
      memory = { interval = 10; format = "󰾆 {used:0.1f}G"; };
      battery = {
        states = { warning = 30; critical = 15; };
        format = "{icon} {capacity}%";
        format-charging = "󰂄 {capacity}%";
        format-icons = [ "󰁺" "󰁼" "󰁾" "󰂀" "󰂂" "󰁹" ];
      };
      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "󰝟";
        format-icons.default = [ "󰕿" "󰖀" "󰕾" ];
        on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
      };
      network = {
        format-wifi = "󰤨 {essid}";
        format-ethernet = "󰈁 {ifname}";
        format-disconnected = "󰤭";
        tooltip-format = "{ipaddr}";
        on-click = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
      };
      bluetooth = {
        format = "󰂯";
        format-connected = "󰂱 {num_connections}";
        on-click = "${pkgs.blueman}/bin/blueman-manager";
      };
      tray = { icon-size = 16; spacing = 6; };
      "custom/power" = {
        format = "⏻";
        tooltip = false;
        on-click = "${powerMenu}";
      };
    };

    style = /* css */ ''
      * {
        font-family: "${fontName}";
        font-weight: bold;
        font-size: 13px;
        min-height: 0;
      }
      window#waybar { background: transparent; }
      tooltip {
        background: alpha(${hx.base00}, 0.9);
        color: ${hx.base05};
        border: 1px solid ${hx.base0C};
        border-radius: 8px;
      }
      #workspaces { background: alpha(${hx.base00}, 0.6); border-radius: 12px; margin: 4px 6px; padding: 0 4px; }
      #workspaces button { color: ${hx.base05}; padding: 0 6px; border-radius: 9px; }
      #workspaces button.active {
        background: linear-gradient(45deg, ${hx.base0E}, ${hx.base0C});
        color: ${hx.base00};
      }
      #workspaces button:hover { background: alpha(${hx.base0C}, 0.4); color: ${hx.base0C}; }
      #window { color: ${hx.base05}; }
      #clock, #cpu, #temperature, #memory, #battery, #pulseaudio,
      #network, #bluetooth, #tray, #custom-power {
        background: alpha(${hx.base00}, 0.6);
        color: ${hx.base05};
        padding: 0 10px;
        margin: 4px 2px;
        border-radius: 10px;
      }
      #clock { background: alpha(${hx.base0D}, 0.25); color: ${hx.base0C}; }
      #custom-power { color: ${hx.base08}; padding: 0 12px; }
      #battery.warning { color: ${hx.base0A}; }
      #battery.critical { color: ${hx.base08}; }
      #temperature.critical { color: ${hx.base08}; }
    '';
  };
}
