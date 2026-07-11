{ lib, pkgs, config, ... }:
# Session Niri (compositeur Wayland scrollable), en parallèle de GNOME/Hyprland.
# Themée Stylix, réutilise les modules rice, et intègre les shaders GLSL
# d'animation open/close (liixini/shaders).
let
  animatedWp = config.athena.animatedWallpaper;
  term = config.athena.terminal;

  cyberpunkMp4 = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Immelancholy/Nix-Relic/main/backgrounds/Cyberpunk.mp4";
    sha256 = "sha256-wnf5FPsLIjkjFZ6fPWlcbfdV7MANOCfKDCQj7fg3b74=";
  };

  # Dépôt de shaders GLSL pour Niri (animations par fenêtre).
  shadersSrc = pkgs.fetchFromGitHub {
    owner = "liixini";
    repo = "shaders";
    rev = "a28d2298c7c70e0e5c7d2c0780f32d108448bf9c";
    sha256 = "sha256-t0ACAM2keQIP9bdeC7JQbeJyiWYu9zq1S5ic48tkB9U=";
  };

  # Les fichiers du repo sont parfois incomplets (accolade finale manquante) :
  # on referme automatiquement le nombre d'accolades manquantes.
  mkShader = path:
    let
      body = builtins.readFile path;
      opens = (builtins.length (lib.splitString "{" body)) - 1;
      closes = (builtins.length (lib.splitString "}" body)) - 1;
      missing = opens - closes;
    in
    body + (lib.concatStrings (lib.genList (_: "}") (if missing > 0 then missing else 0)));

  shaderName = config.athena.niriShader;
  openShader = mkShader "${shadersSrc}/${shaderName}/open.glsl";
  closeShader = mkShader "${shadersSrc}/${shaderName}/close.glsl";

  # Script de veille cybersécurité FR (CERT-FR / ANSSI) exposé dans le PATH
  # sous le nom `cert-fr-news` (appelé par conky via execpi).
  certFrNews = pkgs.writeScriptBin "cert-fr-news" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ./cert-fr-news.py}
  '';

  # 2e agrégateur : blogs/presse cyber FR (undernews, JdH, cyber-sécurité…).
  veilleBlogs = pkgs.writeScriptBin "veille-blogs" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ./veille-blogs.py}
  '';
in
{
  options.athena.enableNiri =
    lib.mkEnableOption "Session Niri (scrollable-tiling) avec shaders GLSL, en plus de GNOME/Hyprland";

  options.athena.niriShader = lib.mkOption {
    type = lib.types.str;
    default = "glass-warp";
    description = "Nom du shader liixini/shaders pour les animations open/close (ex: glass-warp, dissolve, ripple).";
  };

  config = lib.mkIf config.athena.enableNiri {
    # Active Niri : paquet + session Wayland (SDDM la proposera) + portails.
    programs.niri.enable = true;

    environment.systemPackages = with pkgs; [
      xwayland-satellite   # support XWayland pour Niri
      swaybg
      brightnessctl
    ];

    home-manager.users.${config.athena.homeManagerUser} = { pkgs, config, ... }:
    let
      # ===== Palette Mr Robot / CRT phosphore (vert sur noir), propre à Niri =====
      g = {
        bg     = "0a0f0a"; # noir légèrement verdâtre
        bg2    = "0d160d";
        line   = "1f4d1f"; # bordure inactive / dim
        mid    = "00b32d";
        fg     = "00ff41"; # vert phosphore (Matrix)
        bright = "39ff14"; # vert néon
        warn   = "ffb000"; # ambre
        crit   = "ff2b2b"; # rouge
      };
      activeFrom = "#${g.fg}";
      activeTo   = "#${g.bright}";
      inactive   = "#${g.line}";
      urgent     = "#${g.crit}";

      home = config.home.homeDirectory;

      # Sous Niri : PAS de wallpaper -> conky plein écran (thème haxOS porté
      # en Wayland). Deux surfaces layer-shell de fond : moniteur + horloge.
      wallpaperSpawn = ''
        spawn-sh-at-startup "${pkgs.conky}/bin/conky -c ${home}/.config/conky/haxos-monitor.conf"
        spawn-sh-at-startup "${pkgs.conky}/bin/conky -c ${home}/.config/conky/haxos-host.conf"
        spawn-sh-at-startup "${pkgs.conky}/bin/conky -c ${home}/.config/conky/haxos-clock.conf"
        spawn-sh-at-startup "${pkgs.conky}/bin/conky -c ${home}/.config/conky/haxos-cal.conf"
        spawn-sh-at-startup "${pkgs.conky}/bin/conky -c ${home}/.config/conky/haxos-cyber.conf"
        spawn-sh-at-startup "${pkgs.conky}/bin/conky -c ${home}/.config/conky/haxos-veille2.conf"'';

      # Terminal + rofi verts (confs dédiées ci-dessous).
      # wezterm est session-aware (vert CRT quand NIRI_SOCKET est défini).
      greenTerm = "${pkgs.wezterm}/bin/wezterm";
      greenRofi = "${pkgs.rofi}/bin/rofi -theme ${home}/.config/rofi/mrrobot.rasi";

      # ---- Web-apps : services sans client Linux natif, en fenêtre dédiée
      # (chromium --app) avec un app-id custom (--class) pour le placement par
      # workspace. On utilise chromium (≠ google-chrome de WS3) pour éviter les
      # collisions d'app-id. ----
      webApp = id: url: pkgs.writeShellScriptBin "humanix-${id}" ''
        exec ${pkgs.chromium}/bin/chromium --app=${url} --class=humanix-${id} \
          --user-data-dir="$HOME/.local/share/humanix-webapps/${id}" "$@"
      '';
      waWhatsapp = webApp "whatsapp" "https://web.whatsapp.com";
      waChatgpt  = webApp "chatgpt"  "https://chatgpt.com";
      waGemini   = webApp "gemini"   "https://gemini.google.com/app";
      waGrok     = webApp "grok"     "https://grok.com";

      # ---- rofi : thème CRT vert ----
      rofiMrRobot = ''
        * {
            bg:     #${g.bg}f2;
            bg-alt: #${g.bg2};
            fg:     #${g.fg};
            accent: #${g.bright};
            background-color: transparent;
            text-color:       @fg;
            font: "JetBrainsMono Nerd Font Mono 12";
        }
        window   { transparency: "real"; location: center; width: 620px;
                   border: 2px solid; border-radius: 10px; border-color: @accent; background-color: @bg; }
        mainbox  { padding: 14px; spacing: 10px; }
        inputbar { padding: 10px 14px; spacing: 8px; border: 1px solid; border-color: @accent;
                   border-radius: 6px; background-color: @bg-alt; children: [ "prompt", "entry" ]; }
        prompt   { text-color: @accent; }
        entry    { placeholder: "> ./search_"; placeholder-color: #${g.line}; }
        listview { lines: 9; spacing: 2px; scrollbar: false; }
        element  { padding: 6px 10px; spacing: 8px; border-radius: 4px; }
        element selected { background-color: @accent; text-color: #${g.bg}; }
        element-text { text-color: inherit; background-color: transparent; }
        element-icon { size: 1.1em; background-color: transparent; }
      '';

      # ---- waybar (Niri) : config + style CRT vert (avec glow) ----
      waybarNiriConfig = builtins.toJSON {
        layer = "top"; position = "top"; height = 28; spacing = 6;
        modules-left = [ "niri/workspaces" "niri/window" ];
        modules-center = [ "clock" ];
        modules-right = [ "cpu" "memory" "temperature" "battery" "pulseaudio" "network" "tray" ];
        "niri/workspaces" = { format = "{index}"; };
        "niri/window" = { format = "{}"; max-length = 60; };
        clock = { format = "[ {:%H:%M:%S} ]"; interval = 1; format-alt = "[ {:%Y-%m-%d} ]"; };
        cpu = { format = "CPU {usage}%"; interval = 3; };
        memory = { format = "MEM {used:0.1f}G"; };
        temperature = { format = "{temperatureC}°C"; critical-threshold = 85; };
        battery = { format = "BAT {capacity}%"; format-charging = "CHG {capacity}%"; states = { warning = 30; critical = 15; }; };
        pulseaudio = { format = "VOL {volume}%"; format-muted = "MUTE"; };
        network = { format-wifi = "NET {essid}"; format-ethernet = "NET eth"; format-disconnected = "NET --"; };
        tray = { spacing = 6; };
      };
      waybarNiriCss = ''
        * {
          font-family: "Zekton";
          font-size: 14px;
          font-weight: bold;
          min-height: 0;
        }
        window#waybar { background: rgba(10,15,10,0.78); color: #${g.fg}; }
        #workspaces button, #clock, #cpu, #memory, #temperature, #battery,
        #pulseaudio, #network, #window, #tray {
          color: #${g.fg};
          padding: 0 10px;
          text-shadow: 0 0 4px #${g.fg};
        }
        #workspaces button.active { color: #${g.bg}; background: #${g.fg}; border-radius: 2px; }
        #clock { color: #${g.bright}; text-shadow: 0 0 6px #${g.bright}; }
        #battery.warning { color: #${g.warn}; text-shadow: 0 0 4px #${g.warn}; }
        #battery.critical, #temperature.critical { color: #${g.crit}; text-shadow: 0 0 5px #${g.crit}; }
      '';
    in
    {
      # Apps TUI partagées (btop/cava/yazi…). PAS waybar/rofi partagés : sous
      # Niri on utilise des confs vertes dédiées lancées explicitement.
      imports = [
        ../hyprland/rice/apps.nix
      ];

      home.packages = (with pkgs; [
        waybar rofi wezterm conky
        # ---- Apps épinglées par workspace (Humanix) ----
        antigravity vscodium              # WS2 : IDE agentique Google + éditeur codium
        google-chrome chromium            # WS3 : navigateurs (firefox déjà fourni ; safari -> chrome)
        discord teams-for-linux slack      # WS4 : chat pro/perso (+ WhatsApp web)
        thunderbird                        # WS6 : mail
      ]) ++ [
        certFrNews veilleBlogs
        waWhatsapp waChatgpt waGemini waGrok   # web-apps (WS4/WS5)
      ];
      programs.swaylock.enable = true;

      xdg.configFile."rofi/mrrobot.rasi".text = rofiMrRobot;
      xdg.configFile."conky/haxos-monitor.conf".source = ./haxos-monitor.conf;
      xdg.configFile."conky/haxos-host.conf".source = ./haxos-host.conf;
      xdg.configFile."conky/haxos-clock.conf".source = ./haxos-clock.conf;
      xdg.configFile."conky/haxos-cal.conf".source = ./haxos-cal.conf;
      xdg.configFile."conky/haxos-cyber.conf".source = ./haxos-cyber.conf;
      xdg.configFile."conky/haxos-veille2.conf".source = ./haxos-veille2.conf;
      xdg.configFile."waybar-niri/config".text = waybarNiriConfig;
      xdg.configFile."waybar-niri/style.css".text = waybarNiriCss;

      xdg.configFile."niri/config.kdl".text = ''
        // Config Niri — générée par Athena (Stylix + shaders liixini)
        prefer-no-csd

        input {
            keyboard {
                xkb {
                    layout "fr"
                    variant "oss"
                }
            }
            touchpad {
                tap
                natural-scroll
            }
            focus-follows-mouse max-scroll-amount="0%"
        }

        layout {
            gaps 6
            center-focused-column "never"
            background-color "#0a0f0a"

            preset-column-widths {
                proportion 0.33333
                proportion 0.5
                proportion 0.66667
            }
            default-column-width { proportion 0.5; }

            focus-ring { off; }

            border {
                on
                width 2
                inactive-color "${inactive}"
                urgent-color "${urgent}"
                active-gradient from="${activeFrom}" to="${activeTo}" angle=45 relative-to="workspace-view"
            }

            shadow {
                on
                softness 30
                spread 5
                offset x=0 y=5
                color "#00000088"
            }
        }

        // ----- Autostart -----
        spawn-sh-at-startup "${pkgs.waybar}/bin/waybar -c ${home}/.config/waybar-niri/config -s ${home}/.config/waybar-niri/style.css"
        ${wallpaperSpawn}
        spawn-at-startup "nm-applet" "--indicator"
        spawn-at-startup "xwayland-satellite"

        // ----- Humanix : workspaces nommés (ordre = index 1..6) -----
        workspace "term"
        workspace "ide"
        workspace "web"
        workspace "chat"
        workspace "llm"
        workspace "mail"

        // ----- Apps épinglées, auto-lancées (commenter une ligne pour la désactiver) -----
        spawn-sh-at-startup "${greenTerm}"
        spawn-at-startup "antigravity"
        spawn-at-startup "codium"
        spawn-at-startup "firefox"
        spawn-at-startup "google-chrome-stable"
        spawn-sh-at-startup "humanix-whatsapp"
        spawn-at-startup "Discord"
        spawn-at-startup "teams-for-linux"
        spawn-at-startup "slack"
        spawn-at-startup "claude-desktop"
        spawn-sh-at-startup "humanix-chatgpt"
        spawn-sh-at-startup "humanix-gemini"
        spawn-sh-at-startup "humanix-grok"
        spawn-at-startup "thunderbird"

        hotkey-overlay { skip-at-startup; }

        // ----- Animations : shaders GLSL (${shaderName}) -----
        animations {
            window-open {
                duration-ms 500
                custom-shader r#"
        ${openShader}
                "#
            }
            window-close {
                duration-ms 500
                custom-shader r#"
        ${closeShader}
                "#
            }
        }

        // Coins arrondis
        window-rule {
            geometry-corner-radius 10
            clip-to-geometry true
        }

        // ----- Humanix : placement des apps par workspace (match app-id) -----
        window-rule {
            match app-id="org.wezfurlong.wezterm"
            open-on-workspace "term"
            default-column-width { proportion 1.0; }
        }
        window-rule { match app-id="[Aa]ntigravity"; open-on-workspace "ide"; }
        window-rule { match app-id="[Cc]odium"; open-on-workspace "ide"; }
        window-rule { match app-id="firefox"; open-on-workspace "web"; }
        window-rule { match app-id="google-chrome"; open-on-workspace "web"; }
        window-rule { match app-id="whatsapp"; open-on-workspace "chat"; }
        window-rule { match app-id="[Dd]iscord"; open-on-workspace "chat"; }
        window-rule { match app-id="teams"; open-on-workspace "chat"; }
        window-rule { match app-id="[Ss]lack"; open-on-workspace "chat"; }
        window-rule { match app-id="^electron$"; open-on-workspace "llm"; }
        window-rule { match app-id="chatgpt"; open-on-workspace "llm"; }
        window-rule { match app-id="gemini"; open-on-workspace "llm"; }
        window-rule { match app-id="grok"; open-on-workspace "llm"; }
        window-rule { match app-id="thunderbird"; open-on-workspace "mail"; }

        // ----- Raccourcis (Mod = Super) -----
        binds {
            Mod+Return { spawn-sh "${greenTerm}"; }
            Mod+D { spawn-sh "${greenRofi} -show drun"; }
            Mod+Q { close-window; }
            Mod+F { fullscreen-window; }
            Mod+V { toggle-window-floating; }
            Super+Shift+L { spawn "swaylock" "-fF"; }
            Mod+Shift+E { quit; }

            // Focus (modèle colonnes/fenêtres de Niri)
            Mod+Left  { focus-column-left; }
            Mod+Right { focus-column-right; }
            Mod+Up    { focus-window-up; }
            Mod+Down  { focus-window-down; }

            // Déplacement
            Mod+Shift+Left  { move-column-left; }
            Mod+Shift+Right { move-column-right; }
            Mod+Shift+Up    { move-window-up; }
            Mod+Shift+Down  { move-window-down; }

            // Largeur de colonne (cycle entre les presets 33/50/66 %)
            Mod+R { switch-preset-column-width; }

            // Workspaces (keysyms AZERTY = touches physiques 1..0)
            Mod+ampersand   { focus-workspace 1; }
            Mod+eacute      { focus-workspace 2; }
            Mod+quotedbl    { focus-workspace 3; }
            Mod+apostrophe  { focus-workspace 4; }
            Mod+parenleft   { focus-workspace 5; }
            Mod+minus       { focus-workspace 6; }
            Mod+egrave      { focus-workspace 7; }
            Mod+underscore  { focus-workspace 8; }
            Mod+ccedilla    { focus-workspace 9; }
            Mod+Shift+ampersand   { move-column-to-workspace 1; }
            Mod+Shift+eacute      { move-column-to-workspace 2; }
            Mod+Shift+quotedbl    { move-column-to-workspace 3; }
            Mod+Shift+apostrophe  { move-column-to-workspace 4; }
            Mod+Shift+parenleft   { move-column-to-workspace 5; }

            // Captures d'écran (intégré à Niri)
            Print { screenshot; }
            Mod+Print { screenshot-window; }

            // Presse-papier (cliphist via rofi)
            Mod+Shift+V { spawn-sh "${pkgs.cliphist}/bin/cliphist list | ${greenRofi} -dmenu | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy"; }

            // Multimédia / luminosité
            XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
            XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
            XF86AudioMute allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
            XF86MonBrightnessUp allow-when-locked=true { spawn "brightnessctl" "set" "5%+"; }
            XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "set" "5%-"; }
        }
      '';
    };
  };
}
