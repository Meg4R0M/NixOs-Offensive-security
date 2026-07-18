{ lib, pkgs, config, inputs, ... }:
# Session Niri (compositeur Wayland scrollable), en parallèle de GNOME/Hyprland.
# Themée Stylix, réutilise les modules rice, et intègre les shaders GLSL
# d'animation open/close (liixini/shaders).
let
  animatedWp = config.humanix.animatedWallpaper;

  # cshell (Quickshell) re-thémé « Mr Robot » : fond noir + éléments verts. Les
  # couleurs Catppuccin sont codées EN DUR dans presque tous les .qml (pas
  # seulement Colors.qml) → on remappe TOUTE la palette au build (sed global),
  # + rename identité, + remplacement du lecteur musique par un moniteur système.
  # Shell de barre : Noctalia (prioritaire) > cshell > waybar.
  noctaliaOn = config.humanix.aesthetic.noctalia.enable;
  noctaliaBin = "${inputs.noctalia.packages.${pkgs.system}.default.overrideAttrs (o: { mesonFlags = (o.mesonFlags or [ ]) ++ [ "-Dtests=disabled" ]; })}/bin/noctalia";
  cshellOn = config.humanix.aesthetic.cshell.enable && !noctaliaOn;
  themedCshell = inputs.cshell.packages.${pkgs.system}.default.overrideAttrs (o: {
    postPatch = (o.postPatch or "") + ''
      # 1) Palette Catppuccin -> Humanix. Fonds -> noir ; textes + accents
      #    « highlight » (logo/workspace actif/lavande/mauve) -> vert ; rouge
      #    réservé au bouton poweroff ; lime pour charge/luminosité.
      find . -name '*.qml' -print0 | xargs -0 sed -i \
        -e 's/#1e1e2e/#0a0f0a/g' -e 's/#181825/#0a0f0a/g' -e 's/#11111b/#0a0f0a/g' \
        -e 's/#313244/#123312/g' -e 's/#414559/#123312/g' -e 's/#585b70/#123312/g' \
        -e 's/#45475a/#1f4d1f/g' -e 's/#626880/#1f6d2f/g' \
        -e 's/#cdd6f4/#00ff41/g' -e 's/#a6adc8/#00cc33/g' -e 's/#6c7086/#1f8f3f/g' \
        -e 's/#cba6f7/#00ff41/g' -e 's/#ca9ee6/#00ff41/g' -e 's/#a6d189/#00ff41/g' \
        -e 's/#a6e3a1/#00ff41/g' -e 's/#f38ba8/#00ff41/g' -e 's/#b4befe/#00cc33/g' \
        -e 's/#89b4fa/#00d38a/g' -e 's/#8caaee/#00d38a/g' \
        -e 's/#eba0ac/#ff2b2b/g' -e 's/#e78284/#ff2b2b/g' \
        -e 's/#f9e2af/#c8ff00/g' -e 's/#e5c890/#c8ff00/g' \
        -e 's/"1e1e2e"/"#0a0f0a"/g'
      # 2) Identité : chaeu@nixos -> Meg4R0M@NixOs
      sed -i 's/chaeu@nixos/Meg4R0M@NixOs/' popups/DashBoard.qml
      # 3) Lecteur musique -> moniteur système (CPU/MEM/NET/BAT). Swap du composant,
      #    puis dépôt du fichier final APRÈS le sed (couleurs déjà finales).
      sed -i 's/MusicPlayer {id: player}/SysMonitor {id: player}/' popups/DashBoard.qml
      cp ${./cshell/SysMonitor.qml} popups/SysMonitor.qml
      # 4) Fix wifi : cshell prend Networking.devices.values[0] (souvent PAS le
      #    wifi -> « Not Connected » à tort). On sélectionne le device DeviceType.Wifi.
      substituteInPlace services/System.qml \
        --replace 'property var nwDevice: Networking.devices.values[0];' 'property var nwDevice: {
          const ds = Networking.devices.values;
          for (let i = 0; i < ds.length; i++) if (ds[i].type === DeviceType.Wifi) return ds[i];
          return ds.length ? ds[0] : null;
        }' \
        --replace 'property bool wifiConnected: nwDevice.connected;' 'property bool wifiConnected: nwDevice ? nwDevice.connected : false;'
      # 5) Fix backlight : cshell lit /sys/class/backlight/intel_backlight, or ce
      #    laptop est AMD -> amdgpu_bl1 (sinon brightness = 0).
      substituteInPlace services/System.qml --replace 'intel_backlight' 'amdgpu_bl1'
      # 6) Control center (réglages rapides) : dépôt + chemins outils absolus +
      #    déclencheur (icône) injecté dans la barre (ouvre le BotLeftPopup).
      cp ${./cshell/ControlCenter.qml} popups/ControlCenter.qml
      substituteInPlace popups/ControlCenter.qml \
        --replace '@nmcli@' '${pkgs.networkmanager}/bin/nmcli' \
        --replace '@rfkill@' '${pkgs.util-linux}/bin/rfkill' \
        --replace '@brightnessctl@' '${pkgs.brightnessctl}/bin/brightnessctl'
      # 7) Widgets end-4 réimplémentés natifs cshell (tout vert) :
      #    média (MPRIS) / presse-papier (cliphist) / centre de notifs / launcher.
      cp ${./cshell/MediaPlayer.qml} popups/MediaPlayer.qml
      cp ${./cshell/NotifStore.qml}  popups/NotifStore.qml
      cp ${./cshell/NotifCenter.qml} popups/NotifCenter.qml
      cp ${./cshell/GlobalStates.qml} popups/GlobalStates.qml
      cp ${./cshell/Launcher.qml}    popups/Launcher.qml
      cp ${./cshell/ClipHist.qml}    popups/ClipHist.qml
      substituteInPlace popups/ClipHist.qml \
        --replace '@cliphist@' '${pkgs.cliphist}/bin/cliphist' \
        --replace '@wlcopy@'   '${pkgs.wl-clipboard}/bin/wl-copy'
      # Historique notifs : le NotificationServer existant alimente NotifStore.
      substituteInPlace popups/Notification.qml \
        --replace 'import qs.components' 'import qs.components
import qs.popups' \
        --replace 'loader.active = true' 'loader.active = true
      NotifStore.add(notification.summary, notification.body, notification.appName)'
      # Launcher : fenêtre focusable ajoutée à la racine du shell (isolée).
      substituteInPlace shell.qml --replace 'ShellRoot {' 'ShellRoot {
  Launcher {}'
      # Barre : composants + déclencheurs (icônes) + logo = launcher.
      substituteInPlace bar/Bar.qml \
        --replace 'id: logo' 'id: logo
    MouseArea { anchors.fill: parent; onClicked: GlobalStates.launcherOpen = true }' \
        --replace 'implicitWidth: Tokens.barSize' 'implicitWidth: Tokens.barSize

  Component { id: ccComp;    ControlCenter {} }
  Component { id: notifComp; NotifCenter {} }
  Component { id: mediaComp; MediaPlayer {} }
  Component { id: clipComp;  ClipHist {} }' \
        --replace 'Clock {' 'Icon {
      Layout.alignment: Qt.AlignHCenter
      icon: "󰒓"; textSize: 20
      MouseArea { anchors.fill: parent; onClicked: { PopupComm.blComponent = ccComp; PopupComm.showBL(380, 470) } }
    }
    Icon {
      Layout.alignment: Qt.AlignHCenter
      icon: "󰂚"; textSize: 20
      MouseArea { anchors.fill: parent; onClicked: { PopupComm.blComponent = notifComp; PopupComm.showBL(400, 500) } }
    }
    Icon {
      Layout.alignment: Qt.AlignHCenter
      icon: "󰎈"; textSize: 20
      MouseArea { anchors.fill: parent; onClicked: { PopupComm.blComponent = mediaComp; PopupComm.showBL(340, 300) } }
    }
    Icon {
      Layout.alignment: Qt.AlignHCenter
      icon: "󰅍"; textSize: 20
      MouseArea { anchors.fill: parent; onClicked: { PopupComm.blComponent = clipComp; PopupComm.showBL(440, 540) } }
    }
    Clock {'
    '';
  });

  # niri-glass : effet verre dépoli SUBTIL. Injecté dans le KDL UNIQUEMENT si le
  # toggle est ON (sinon niri standard planterait sur le node `liquid-glass`).
  # xray requis (sinon artefacts aux bords) ; réfraction/distorsion basses +
  # fringing/lens à 0 pour rester proche du CRT plat ; opacité 0.94 = à peine
  # translucide (nécessaire pour que l'effet derrière la fenêtre soit visible).
  glassOn = config.humanix.aesthetic.niriGlass.enable;
  glassRule = lib.optionalString glassOn ''
    // ----- niri-glass : verre dépoli subtil (fork zaroutt/Niri-glass) -----
    window-rule {
        match app-id=".*"
        background-effect {
            blur true
            xray true
            liquid-glass {
                refraction-strength 0.5
                power-factor 3
                refraction-power 0.4
                glow-weight 0.03
                edge-lighting 0.35
                fringing 0
                lens-distortion 0
                physical-refraction 0
                saturation 0.9
                vibrancy 0.15
                adaptive-dim 0.2
                adaptive-boost 0.2
                edge-thickness 0.1
            }
        }
    }
  '';
  term = config.humanix.terminal;

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

  shaderName = config.humanix.niriShader;
  openShader = mkShader "${shadersSrc}/${shaderName}/open.glsl";
  closeShader = mkShader "${shadersSrc}/${shaderName}/close.glsl";
  # Durée (ms) des animations glitch open/close. Plus long => plus visible sur les
  # grandes fenêtres tuilées, pas seulement les popups.
  shaderDurationMs = config.humanix.niriShaderDuration;
  # Opacité des fenêtres (transparence "on distingue derrière"). Le flou niri-glass
  # rend le fond visible joliment. wezterm (~0.92) se cumule pour les terminaux.
  winOpacity = config.humanix.niriOpacity;
  winOpacityFocused = config.humanix.niriOpacityFocused;

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

  # Dashboard RÉSEAU haxOS (STATISTICS/ROUTING/ACTIVE+UDP/LISTENING/LAN_DISCOVERY),
  # appelé par conky (haxos-netmon.conf) via execpi. arp-scan via wrapper setcap
  # (scan LAN complet) sinon repli ip neigh + base OUI d'arp-scan (vendors, sans root).
  netmon = pkgs.writeShellScriptBin "humanix-netmon" ''
    export HUMANIX_OUI="${pkgs.arp-scan}/share/arp-scan/ieee-oui.txt"
    export HUMANIX_ARPSCAN="/run/wrappers/bin/arp-scan"
    export PATH="${pkgs.lib.makeBinPath [ pkgs.iproute2 pkgs.gnugrep pkgs.gnused pkgs.gawk pkgs.coreutils pkgs.arp-scan ]}:$PATH"
    ${builtins.readFile ./humanix-netmon.sh}
  '';
in
{
  options.humanix.enableNiri =
    lib.mkEnableOption "Session Niri (scrollable-tiling) avec shaders GLSL, en plus de GNOME/Hyprland";

  options.humanix.niriShader = lib.mkOption {
    type = lib.types.str;
    default = "glass-warp";
    description = "Nom du shader liixini/shaders pour les animations open/close (ex: glass-warp, dissolve, ripple).";
  };

  options.humanix.niriShaderDuration = lib.mkOption {
    type = lib.types.int;
    default = 1000;
    description = "Durée (ms) des animations glitch open/close. Plus long = glitch plus franc (défaut 1000, était 500).";
  };

  # Opacité HORS focus (fenêtres inactives) : bien transparent -> elles s'effacent.
  options.humanix.niriOpacity = lib.mkOption {
    type = lib.types.float;
    default = 0.70;
    description = "Opacité des fenêtres niri HORS focus (inactives). Plus bas = plus transparent.";
  };

  # Opacité de la fenêtre ACTIVE : quasi opaque -> nette, sans voile vert du glass.
  options.humanix.niriOpacityFocused = lib.mkOption {
    type = lib.types.float;
    default = 0.96;
    description = "Opacité de la fenêtre niri ACTIVE (au focus). Monte à 1.0 pour supprimer tout voile.";
  };

  config = lib.mkIf config.humanix.enableNiri {
    # Active Niri : paquet + session Wayland (SDDM la proposera) + portails.
    programs.niri.enable = true;
    # Swap du binaire niri par le fork niri-glass si le toggle est ON (sinon on
    # laisse le paquet niri par défaut). Réutilise tout le câblage session upstream.
    programs.niri.package = lib.mkIf glassOn inputs.niri-glass.packages.${pkgs.system}.niri-glass;

    environment.systemPackages = with pkgs; [
      xwayland-satellite   # support XWayland pour Niri
      swaybg
      brightnessctl
    ];

    # arp-scan avec CAP_NET_RAW => scan LAN complet du dashboard réseau
    # (humanix-netmon). Sans ça, repli passif ip neigh + base OUI (vendors OK).
    security.wrappers.arp-scan = {
      source = "${pkgs.arp-scan}/bin/arp-scan";
      capabilities = "cap_net_raw+ep";
      owner = "root";
      group = "root";
    };

    home-manager.users.${config.humanix.homeManagerUser} = { pkgs, config, ... }:
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
        // Fond d'écran : swaybg SEULEMENT si Noctalia ne gère pas le wallpaper
        // (Noctalia rend sa propre couche par-dessus, avec TON image via sa conf).
        ${lib.optionalString (!noctaliaOn) ''spawn-sh-at-startup "${pkgs.swaybg}/bin/swaybg -m center -c '#000000' -i ${home}/Images/wallpappers/black-terminals-with-green-font-colors-quote-6g-2880x1800.jpg"''}
        spawn-sh-at-startup "${pkgs.conky}/bin/conky -c ${home}/.config/conky/haxos-monitor.conf"
        spawn-sh-at-startup "${pkgs.conky}/bin/conky -c ${home}/.config/conky/haxos-host.conf"
        spawn-sh-at-startup "${pkgs.conky}/bin/conky -c ${home}/.config/conky/haxos-clock.conf"
        spawn-sh-at-startup "${pkgs.conky}/bin/conky -c ${home}/.config/conky/haxos-cal.conf"
        spawn-sh-at-startup "${pkgs.conky}/bin/conky -c ${home}/.config/conky/haxos-cyber.conf"
        spawn-sh-at-startup "${pkgs.conky}/bin/conky -c ${home}/.config/conky/haxos-veille2.conf"
        spawn-sh-at-startup "${pkgs.conky}/bin/conky -c ${home}/.config/conky/haxos-netmon.conf"'';

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
      waChatgpt  = webApp "chatgpt"  "https://chatgpt.com";
      waGemini   = webApp "gemini"   "https://gemini.google.com/app";
      waGrok     = webApp "grok"     "https://grok.com";
      waClaude   = webApp "claude"   "https://claude.ai";
      waDeepseek = webApp "deepseek" "https://chat.deepseek.com";

      # ---- rofi : thème CRT vert ----
      rofiMrRobot = ''
        * {
            bg:     #${g.bg}f2;
            bg-alt: #${g.bg2};
            fg:     #${g.fg};
            accent: #${g.bright};
            background-color: transparent;
            text-color:       @fg;
            font: "VictorMono Nerd Font Mono 12";
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
        discord teams-for-linux ferdium    # WS4 : Discord/Teams NATIFS (appels/partage écran) + Ferdium (Slack/WhatsApp/… en 1 seul Chromium = léger)
        thunderbird                        # WS6 : mail
      ]) ++ [
        certFrNews veilleBlogs netmon
        waChatgpt waGemini waGrok waClaude waDeepseek   # web-apps LLM (WS5) : les 5 IA
      ] ++ lib.optional cshellOn themedCshell;  # commande `cshell` (barre thémée vert)
      programs.swaylock.enable = true;

      xdg.configFile."rofi/mrrobot.rasi".text = rofiMrRobot;
      xdg.configFile."conky/haxos-monitor.conf".source = ./haxos-monitor.conf;
      xdg.configFile."conky/haxos-host.conf".source = ./haxos-host.conf;
      xdg.configFile."conky/haxos-clock.conf".source = ./haxos-clock.conf;
      xdg.configFile."conky/haxos-cal.conf".source = ./haxos-cal.conf;
      xdg.configFile."conky/haxos-cyber.conf".source = ./haxos-cyber.conf;
      xdg.configFile."conky/haxos-veille2.conf".source = ./haxos-veille2.conf;
      xdg.configFile."conky/haxos-netmon.conf".source = ./haxos-netmon.conf;
      xdg.configFile."waybar-niri/config".text = waybarNiriConfig;
      xdg.configFile."waybar-niri/style.css".text = waybarNiriCss;

      xdg.configFile."niri/config.kdl".text = ''
        // Config Niri — générée par Athena (Stylix + shaders liixini)
        prefer-no-csd

        // Écran interne en scale 1.0 : on exploite toute la densité 2880x1800
        // (au lieu du 1.5 auto). Rend l'UI plus petite mais plus d'espace utile.
        output "eDP-1" {
            scale 1.0
        }

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
        // Shell/barre : Noctalia (thémé vert) > cshell > waybar.
        ${if noctaliaOn then ''spawn-at-startup "${noctaliaBin}"''
          else if cshellOn then ''spawn-at-startup "${themedCshell}/bin/cshell"''
          else ''spawn-sh-at-startup "${pkgs.waybar}/bin/waybar -c ${home}/.config/waybar-niri/config -s ${home}/.config/waybar-niri/style.css"''}
        ${wallpaperSpawn}
        spawn-at-startup "nm-applet" "--indicator"
        spawn-at-startup "xwayland-satellite"
        // 2-en-1 : rotation auto de l'écran via l'accéléromètre (OmniBook Flip)
        spawn-at-startup "humanix-autorotate"

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
        spawn-at-startup "Discord"
        spawn-at-startup "teams-for-linux"
        spawn-at-startup "ferdium"
        spawn-at-startup "claude-desktop"
        spawn-sh-at-startup "humanix-chatgpt"
        spawn-sh-at-startup "humanix-gemini"
        spawn-sh-at-startup "humanix-grok"
        spawn-at-startup "thunderbird"

        hotkey-overlay { skip-at-startup; }

        // ----- Animations : shaders GLSL (${shaderName}) -----
        animations {
            window-open {
                duration-ms ${toString shaderDurationMs}
                custom-shader r#"
        ${openShader}
                "#
            }
            window-close {
                duration-ms ${toString shaderDurationMs}
                custom-shader r#"
        ${closeShader}
                "#
            }
        }

        // Coins arrondis + transparence HORS focus (les inactives s'effacent).
        window-rule {
            geometry-corner-radius 10
            clip-to-geometry true
            opacity ${toString winOpacity}
        }
        // Fenêtre ACTIVE : bien moins transparente -> nette, sans voile vert du glass.
        window-rule {
            match is-active=true
            opacity ${toString winOpacityFocused}
        }
        ${glassRule}
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
        window-rule { match app-id="[Ff]erdium"; open-on-workspace "chat"; }
        window-rule { match app-id="[Dd]iscord"; open-on-workspace "chat"; }
        window-rule { match app-id="teams"; open-on-workspace "chat"; }
        window-rule { match app-id="^electron$"; open-on-workspace "llm"; }
        window-rule { match app-id="chatgpt"; open-on-workspace "llm"; }
        window-rule { match app-id="gemini"; open-on-workspace "llm"; }
        window-rule { match app-id="grok"; open-on-workspace "llm"; }
        window-rule { match app-id="humanix-claude"; open-on-workspace "llm"; }
        window-rule { match app-id="humanix-deepseek"; open-on-workspace "llm"; }
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

            // 2-en-1 (OmniBook Flip) : clavier écran + verrou de rotation
            Mod+K { spawn-sh "humanix-osk-toggle"; }
            Mod+Shift+R { spawn-sh "humanix-autorotate-toggle"; }

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
