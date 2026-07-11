{ lib, config, ... }: {
  config = lib.mkIf (config.athena.terminal == "wezterm") {
    home-manager.users.${config.athena.homeManagerUser}.programs.wezterm = {
      enable = true;
      # Session-aware : sous Niri (NIRI_SOCKET défini) -> thème Mr Robot vert CRT ;
      # ailleurs (GNOME/Hyprland) -> color scheme "stylix" (généré par Stylix).
      # HM merge cette table dans sa config -> on retourne une TABLE simple
      # (pas de config_builder, dont pairs() ne rendrait pas les clés).
      extraConfig = ''
        local wezterm = require 'wezterm'

        local cfg = {
          font = wezterm.font_with_fallback {
            'JetBrainsMono Nerd Font',
            'Noto Color Emoji',
          },
          font_size = 10.0,
          line_height = 0.95,
          enable_tab_bar = false,
          hide_tab_bar_if_only_one_tab = true,
          window_decorations = 'NONE',
          window_background_opacity = 0.92,
          window_padding = { left = 8, right = 8, top = 8, bottom = 8 },
          audible_bell = 'Disabled',
          check_for_updates = false,
          default_cursor_style = 'BlinkingBlock',
        }

        if os.getenv('NIRI_SOCKET') then
          -- Mr Robot / CRT phosphore (session Niri)
          cfg.window_background_opacity = 0.90
          cfg.colors = {
            foreground   = '#00ff41',
            background   = '#0a0f0a',
            cursor_bg    = '#39ff14',
            cursor_fg    = '#0a0f0a',
            cursor_border = '#39ff14',
            selection_bg = '#00ff41',
            selection_fg = '#0a0f0a',
            ansi    = { '#0a0f0a', '#ff2b2b', '#00ff41', '#ffb000', '#00b32d', '#1f4d1f', '#00ff87', '#00cc36' },
            brights = { '#1f4d1f', '#ff5c5c', '#39ff14', '#ffd257', '#00e63a', '#2f7d2f', '#5cffb0', '#d4ffd4' },
          }
        else
          cfg.color_scheme = 'stylix'
        end

        return cfg
      '';
    };
  };
}
