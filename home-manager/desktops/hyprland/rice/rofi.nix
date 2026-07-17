{ config, lib, pkgs, osConfig, ... }:
# Rofi (Wayland) themé Stylix, look Nix-Relic condensé.
let
  c = config.lib.stylix.colors or null;
  fonts = config.stylix.fonts or null;
  fontName = if fonts != null then fonts.monospace.name else "VictorMono Nerd Font Mono";
in
lib.mkIf (osConfig.humanix.useStylix or false) {
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    font = "${fontName} 12";
    terminal = "${pkgs.kitty}/bin/kitty";
    modes = [ "drun" "run" "filebrowser" "window" ];
    extraConfig = {
      show-icons = true;
      display-drun = " Apps";
      display-run = "󰲌 Run";
      display-filebrowser = " Files";
      display-window = " Win";
      drun-display-format = "{icon} {name}";
    };
    theme =
      let
        inherit (config.lib.formats.rasi) mkLiteral;
        hx = builtins.mapAttrs (_: v: "#${v}") c;
      in
      {
        "*" = {
          bg = mkLiteral "${hx.base00}cc";
          bg-alt = mkLiteral "${hx.base01}";
          fg = mkLiteral "${hx.base05}";
          accent = mkLiteral "${hx.base0C}";
          accent2 = mkLiteral "${hx.base0E}";
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "@fg";
        };
        "window" = {
          transparency = "real";
          location = mkLiteral "center";
          width = mkLiteral "640px";
          border = mkLiteral "2px solid";
          border-radius = mkLiteral "20px";
          border-color = mkLiteral "@accent";
          background-color = mkLiteral "@bg";
        };
        "mainbox" = {
          padding = mkLiteral "16px";
          spacing = mkLiteral "12px";
        };
        "inputbar" = {
          padding = mkLiteral "12px 16px";
          spacing = mkLiteral "10px";
          border-radius = mkLiteral "14px";
          background-color = mkLiteral "@bg-alt";
          children = mkLiteral ''[ "prompt", "entry" ]'';
        };
        "prompt" = { text-color = mkLiteral "@accent"; };
        "entry" = {
          placeholder = "Search…";
          placeholder-color = mkLiteral "${hx.base04}";
        };
        "listview" = {
          lines = mkLiteral "8";
          columns = mkLiteral "1";
          spacing = mkLiteral "4px";
          scrollbar = mkLiteral "false";
        };
        "element" = {
          padding = mkLiteral "8px 12px";
          spacing = mkLiteral "10px";
          border-radius = mkLiteral "12px";
        };
        "element selected" = {
          background-color = mkLiteral "@accent";
          text-color = mkLiteral "${hx.base00}";
        };
        "element-icon" = { size = mkLiteral "1.2em"; background-color = mkLiteral "transparent"; };
        "element-text" = { background-color = mkLiteral "transparent"; text-color = mkLiteral "inherit"; };
      };
  };
}
