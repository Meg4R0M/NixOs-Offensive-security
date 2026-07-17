{ lib, config, ... }: {
  config = lib.mkIf (config.humanix.terminal == "kitty") {
    home-manager.users.${config.humanix.homeManagerUser}.programs.kitty = {
      enable = true;
      settings = {
        font_family = "VictorMono Nerd Font Medium";
        bold_font = "VictorMono Nerd Font Bold";
        italic_font = "VictorMono Nerd Font Italic";
        bold_italic_font = "VictorMono Nerd Font Bold Italic";

        font_size = "12.0";

        adjust_line_height = "92%";

        scrollback_lines = 3000;

        macos_thicken_font = "0.3";

        linux_display_server = "x11";

        confirm_os_window_close = 0;
      };
    };
  };
}
