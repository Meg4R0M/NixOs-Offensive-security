{ lib, config, ... }: {
  config = lib.mkIf config.athena.baseConfiguration {
    home-manager.users.${config.athena.homeManagerUser} = { pkgs, config, osConfig, ... }:
    let
      useStylix = osConfig.athena.useStylix or false;
      c = config.lib.stylix.colors or null;
      fonts = config.stylix.fonts or null;
      fontStr = if fonts != null
        then "${fonts.monospace.name} ${toString fonts.sizes.popups}"
        else "Monospace 12";
    in {
      services.dunst = {
        enable = true;
        # Si Stylix actif : thème dérivé du wallpaper (façon Nix-Relic).
        settings =
          if (useStylix && c != null) then {
            global = {
              follow = "keyboard";
              enable_posix_regex = true;
              frame_color = "#${c.base0C}c0";
              separator_color = "frame";
              highlight = "#${c.base0C}c0";
              gaps_size = 4;
              frame_width = 2;
              corner_radius = 20;
              origin = "top-right";
              offset = "(54, 18)";
              width = "(0, 320)";
              height = "(0, 330)";
              alignment = "center";
              icon_position = "top";
              padding = 15;
              horizontal_padding = 12;
              font = fontStr;
              format = "<b>%s</b>\\n%b";
              mouse_left_click = "do_action, close_current";
              mouse_middle_click = "close_current";
              dmenu = "${pkgs.rofi}/bin/rofi -dmenu";
            };
            urgency_low = { background = "#${c.base00}99"; foreground = "#${c.base05}"; };
            urgency_normal = { background = "#${c.base00}99"; foreground = "#${c.base05}"; };
            urgency_critical = { background = "#${c.base00}99"; foreground = "#${c.base05}"; frame_color = "#${c.base08}c0"; };
          } else {
            global = {
              background = "#285577";
              timeout = 20;
              width = "(300, 600)";
              height = 500;
              origin = "top-center";
              notification_limit = 0;
              font = "Monospace 12";
              format = "<b>%s</b>\\n%b";
              corner_radius = 20;
              force_xwayland = true;
              mouse_left_click = "open_url, close_current";
              mouse_middle_click = "close_current";
              default_icon = "./icons/cve.png";
            };
          };
      };
    };
  };
}

