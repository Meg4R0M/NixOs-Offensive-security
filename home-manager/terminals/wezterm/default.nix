{ lib, config, inputs, ... }: {
  config = lib.mkIf (config.humanix.terminal == "wezterm") {
    home-manager.users.${config.humanix.homeManagerUser}.programs.wezterm = {
      enable = true;
      # Session-aware : sous Niri (NIRI_SOCKET défini) -> thème Mr Robot vert CRT ;
      # ailleurs (GNOME/Hyprland) -> color scheme "stylix" (généré par Stylix).
      # HM merge cette table dans sa config -> on retourne une TABLE simple
      # (pas de config_builder, dont pairs() ne rendrait pas les clés).
      extraConfig = ''
        local wezterm = require 'wezterm'

        -- widgets.wez vendoré (flake input `widgets-wez`, flake = false) : on
        -- l'ajoute au package.path Lua puis on require le module local -> pas de
        -- wezterm.plugin.require (pas de clone git au runtime, 100% pinné/pur).
        package.path = '${inputs.widgets-wez}/plugin/?.lua;' .. package.path

        local cfg = {
          font = wezterm.font_with_fallback {
            'VictorMono Nerd Font Mono',
            'Noto Color Emoji',
          },
          font_size = 10.0,
          line_height = 0.95,
          -- Tab bar RÉACTIVÉE (nécessaire pour la status bar : les widgets
          -- s'affichent via window:set_right_status, rendu dans la tab bar).
          -- Rétro + en bas = vraie « status line » minimale.
          enable_tab_bar = true,
          hide_tab_bar_if_only_one_tab = false,
          use_fancy_tab_bar = false,
          tab_bar_at_bottom = true,
          status_update_interval = 1000,
          window_decorations = 'NONE',
          window_background_opacity = 0.92,
          window_padding = { left = 8, right = 8, top = 8, bottom = 8 },
          audible_bell = 'Disabled',
          check_for_updates = false,
          -- Curseur : bloc vert qui PULSE en douceur (fondu entrée/sortie) au
          -- lieu d'un clignotement sec -> effet CRT phosphore.
          default_cursor_style = 'BlinkingBlock',
          cursor_blink_rate = 650,
          cursor_blink_ease_in = 'EaseIn',
          cursor_blink_ease_out = 'EaseOut',
          animation_fps = 60,
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
            -- Tab bar rétro assortie (vert phosphore sur noir).
            tab_bar = {
              background = '#0a0f0a',
              active_tab         = { bg_color = '#0f160f', fg_color = '#39ff14' },
              inactive_tab       = { bg_color = '#0a0f0a', fg_color = '#1f4d1f' },
              inactive_tab_hover = { bg_color = '#0f160f', fg_color = '#00ff41' },
              new_tab            = { bg_color = '#0a0f0a', fg_color = '#1f4d1f' },
              new_tab_hover      = { bg_color = '#0f160f', fg_color = '#00ff41' },
            },
          }
        else
          cfg.color_scheme = 'stylix'
        end

        -- Widgets système dans le status droit (CPU/RAM/réseau ↓↑/disque/batterie),
        -- tout en vert Mr Robot. apply_to_config n'enregistre qu'un handler global
        -- wezterm.on('update-status') -> lui passer cfg est inoffensif. pcall : si
        -- le plugin ne se charge pas, wezterm démarre quand même.
        local ok, sys = pcall(require, 'systems.init')
        if ok then
          sys.apply_to_config(cfg, {
            right = {
              sys.cpu.utilization.widget({ icon = wezterm.nerdfonts.md_cpu_64_bit, color = '#00ff41', throttle = 2 }),
              sys.ram.utilization.widget({ icon = wezterm.nerdfonts.md_memory, color = '#39ff14', throttle = 2 }),
              sys.network.download.widget({ icon = wezterm.nerdfonts.md_download, color = '#00e63a', throttle = 2 }),
              sys.network.upload.widget({ icon = wezterm.nerdfonts.md_upload, color = '#00cc36', throttle = 2 }),
              sys.disk.space.widget({ icon = wezterm.nerdfonts.md_harddisk, color = '#00b32d', throttle = 10 }),
              sys.battery.charge.widget({ icon = wezterm.nerdfonts.md_battery, color = '#00ff87', throttle = 10 }),
            },
            separator = { text = ' | ', color = '#1f4d1f' },
          })
        end

        return cfg
      '';
    };
  };
}
