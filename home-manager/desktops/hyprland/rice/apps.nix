{ config, lib, pkgs, ... }:
let
  # Clé fastfetch : barre verticale verte (cadre continu à gauche) + icône/label
  # en couleur c, puis reset. Les icônes s'alignent sous le │ des en-têtes.
  k = c: s: "{#green}│  {#${c}}${s}{#}";
in
# Apps perso du rice, themées Stylix. + fastfetch "hacking" custom.
{
  programs = {
    btop.enable = true;            # moniteur système
    cava.enable = true;            # visualiseur audio
    mpv.enable = true;             # lecteur vidéo
    yazi = {
      enable = true;               # gestionnaire de fichiers TUI
      enableZshIntegration = true;
      shellWrapperName = "yy";     # verrouillé (défaut passé à "y" en 26.05)
    };

    # ---------- fastfetch : logo crâne + look terminal hacker ----------
    fastfetch = {
      enable = true;
      settings = {
        logo = {
          # Image DARK-4RMY en blocs Unicode colorés (chafa) : rendu "vraie
          # image" en texte → marche partout (zellij/kitty/wezterm). Taille -20%.
          source = "${config.xdg.configHome}/fastfetch/darkarmy.ans";
          type = "file-raw";
          width = 36;
          height = 26;
          padding = { top = 1; left = 1; right = 3; };
        };

        display = {
          separator = "  ";
          color.title = "green";
        };

        # Disposition encadrée (inspirée de p-shell), adaptée au combo vert/rouge.
        # Barre │ verte CONTINUE à gauche (helper k) : icônes alignées dessous.
        modules = [
          { type = "title"; format = "{#green}╭───────────── {#}{user-name-colored}"; }

          { type = "custom"; format = "{#green}│ {#}{#red}System Information{#}"; }
          { type = "os";       key = k "green" "󰍹 OS"; }
          { type = "host";     key = k "red"   "󰌢 Host"; }
          { type = "kernel";   key = k "green" "󰒋 Kernel"; }
          { type = "uptime";   key = k "red"   "󰅐 Uptime"; }
          { type = "packages"; key = k "green" "󰏖 Packages"; format = "{all}"; }
          { type = "shell";    key = k "red"   "󰞷 Shell"; }
          { type = "locale";   key = k "green" "󰗊 Locale"; }
          { type = "custom"; format = "{#green}│"; }

          { type = "custom"; format = "{#green}│ {#}{#red}Desktop Environment{#}"; }
          { type = "wm";           key = k "green" "󱂬 WM";         format = "{2} {#red}({3}){#}"; }
          { type = "theme";        key = k "red"   "󰉼 Theme"; }
          { type = "icons";        key = k "green" "󰀻 Icons"; }
          { type = "display";      key = k "red"   "󰹑 Resolution"; }
          { type = "cursor";       key = k "green" "󰇀 Cursor"; }
          { type = "terminal";     key = k "red"   "󰆍 Terminal"; }
          { type = "terminalfont"; key = k "green" "󰛖 Font";       format = "{1}"; }
          { type = "custom"; format = "{#green}│"; }

          { type = "custom"; format = "{#green}│ {#}{#red}Hardware Information{#}"; }
          { type = "cpu";     key = k "green" "󰻠 CPU";  format = "{1} {#red}({4}){#} {7}"; }
          { type = "gpu";     key = k "red"   "󰢮 GPU";  format = "{1} {2} {#green}[{6}]{#}"; }
          {
            type = "memory";
            key = k "green" "󰍛 Memory";
            percent = { type = 3; green = 30; yellow = 70; };
            format = "{4} {1}/{2} {#red}({3}){#}";
          }
          { type = "swap"; key = k "red" "󰓡 Swap"; }
          {
            type = "disk";
            key = k "green" "󰋊 Disk (/)";
            folders = "/";
            percent = { type = 3; green = 30; yellow = 70; };
            format = "{13} {1}/{2} {#red}({3}){#}";
          }
          { type = "battery"; key = k "red" "󰁹 Battery"; }
          { type = "custom"; format = "{#green}│"; }

          { type = "custom"; format = "{#green}│ {#}{#red}Network{#}"; }
          { type = "localip"; key = k "green" "󰩟 Local IP"; }
          { type = "custom"; format = "{#green}│"; }

          { type = "colors"; key = "{#green}│  "; symbol = "square"; }
          { type = "custom"; format = "{#green}╰───────────────────────────────╯"; }
        ];
      };
    };
  };

  # Logo DARK-4RMY : image recadrée + convertie en blocs colorés (chafa),
  # stockée telle quelle (contient les codes couleur ANSI 24-bit).
  xdg.configFile."fastfetch/darkarmy.ans".source = ./darkarmy.ans;

  # Historique du presse-papier (Wayland) : démons wl-paste + base cliphist.
  services.cliphist.enable = true;

  home.packages = with pkgs; [
    wl-clipboard
    cliphist
    playerctl
    pamixer
    brightnessctl
    grim
    slurp
  ];
}
