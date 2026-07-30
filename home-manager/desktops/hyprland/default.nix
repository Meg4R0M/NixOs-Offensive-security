{ lib, pkgs, config, ... }:
let
  term = config.humanix.terminal; # "kitty" ou "alacritty"

  # Fond d'écran statique = l'image Stylix (athena-linus-richard), affichée
  # avec swaybg (mode fill).
  wallpaperExec = "exec-once = ${pkgs.swaybg}/bin/swaybg -i ${config.stylix.image} -m fill";

  # Plugin HyprGlass (effet "liquid glass"), packagé depuis la source.
  # Commit épinglé pour Hyprland 0.55.4 (cf. hyprpm.toml upstream).
  hyprglass = pkgs.hyprlandPlugins.mkHyprlandPlugin {
    pluginName = "hyprglass";
    version = "0-unstable-2026-06-19";

    src = pkgs.fetchFromGitHub {
      owner = "hyprnux";
      repo = "hyprglass";
      rev = "7ff4064cbed1ef6e6f703139fca4ec20ba0cbb5b";
      hash = "sha256-e60+3KjFJOIi4DqcpxkeADsdApV+Cso2mwRA9t1Fs3U=";
    };

    dontUseCmakeConfigure = true; # build via Makefile

    buildPhase = ''
      runHook preBuild
      make
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib
      cp hyprglass.so $out/lib/libhyprglass.so
      runHook postInstall
    '';

    meta = {
      description = "Liquid Glass window decoration effect for Hyprland";
      homepage = "https://github.com/hyprnux/hyprglass";
      platforms = lib.platforms.linux;
    };
  };
in {
  options.humanix.animatedWallpaper =
    (lib.mkEnableOption "Wallpaper animé (mpvpaper, vidéo Cyberpunk de Nix-Relic) sous Hyprland") // {
      default = true;
    };

  # Session Hyprland additionnelle, activable en parallèle du desktopManager
  # principal via `humanix.enableHyprland = true`. SDDM (wayland.enable) la
  # proposera automatiquement dans la liste des sessions au login.
  config = lib.mkIf config.humanix.enableHyprland {

    # ---- System Configuration ----
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    # Portails XDG (capture d'écran, file picker, partage...)
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    # Accélération graphique
    hardware.graphics.enable = true;

    environment.systemPackages = with pkgs; [
      waybar              # barre de statut
      swaybg              # fond d'écran (fallback statique)
      libnotify
      grim slurp          # captures d'écran
      wl-clipboard        # presse-papier Wayland
      brightnessctl       # luminosité
      pavucontrol         # son
      pamixer             # contrôle volume CLI (binds multimédia)
      networkmanagerapplet
      playerctl
    ];

    # ---- Home Configuration ----
    home-manager.users.${config.humanix.homeManagerUser} = { pkgs, config, ... }:
    let
      # Couleurs base16 générées par Stylix (look Nix-Relic). Fallback si Stylix off.
      c = config.lib.stylix.colors or null;
      activeBorder =
        if c != null
        then "rgb(${c.base0E}) rgb(${c.base0C}) rgb(${c.base06}) 40deg"
        else "rgba(33ccffee) rgba(00ff99ee) 45deg";
      inactiveBorder =
        if c != null
        then "rgba(${c.base07}cc) rgba(${c.base04}cc) 45deg"
        else "rgba(595959aa)";
      # Teinte du verre HyprGlass dérivée de la palette Stylix (accent + alpha
      # léger), pour que l'effet colle au thème généré depuis le wallpaper.
      glassTint = if c != null then "0x${c.base0D}33" else "0x8899aa22";
    in {
      imports = [
        ./rice/waybar.nix
        ./rice/rofi.nix
        ./rice/apps.nix
      ];

      # Verrouillage d'écran (themé Stylix) + gestion de l'inactivité.
      programs.swaylock.enable = true;
      services.swayidle = {
        enable = true;
        events = {
          before-sleep = "${pkgs.swaylock}/bin/swaylock -fF";
          lock = "${pkgs.swaylock}/bin/swaylock -fF";
        };
        timeouts = [
          { timeout = 600; command = "${pkgs.swaylock}/bin/swaylock -fF"; }
          {
            timeout = 660;
            command = "${pkgs.hyprland}/bin/hyprctl dispatch dpms off";
            resumeCommand = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
          }
        ];
      };

      xdg.configFile."hypr/hyprland.conf".text = ''
        ###################
        ###  PLUGINS    ###
        ###################
        # HyprGlass RETIRÉ (TEMP 2026-07-30) : incompat C++ avec le hyprland récent
        # (CMonitor*/m_windows). Réactiver quand hyprglass suit la nouvelle API.

        ###################
        ###  MONITEURS  ###
        ###################
        monitor = , preferred, auto, 1

        ###################
        ###  CLAVIER    ###
        ###################
        # AZERTY fr (variante oss) — cohérent avec services.xserver.xkb
        input {
            kb_layout = fr
            kb_variant = oss
            kb_options =
            follow_mouse = 1
            touchpad {
                natural_scroll = true
                tap-to-click = true
            }
            sensitivity = 0
        }

        ###################
        ###  AUTOSTART  ###
        ###################
        exec-once = waybar
        ${wallpaperExec}
        exec-once = nm-applet --indicator

        ###################
        ###  APPARENCE  ###
        ###################
        general {
            gaps_in = 3
            gaps_out = 8
            border_size = 2
            col.active_border = ${activeBorder}
            col.inactive_border = ${inactiveBorder}
            resize_on_border = true
            layout = dwindle
        }

        decoration {
            rounding = 20
            # Opacité globale (fenêtres translucides = effet verre visible).
            # Un peu plus basse pour que la réfraction HyprGlass ressorte sur
            # le wallpaper animé, sans nuire à la lisibilité.
            active_opacity = 0.90
            inactive_opacity = 0.82
            # HyprGlass a besoin des ombres dans le pipeline de rendu.
            shadow {
                enabled = true
                range = 5
                render_power = 4
            }
            # Blur natif DÉSACTIVÉ : c'est HyprGlass qui produit le flou/verre
            # (sinon double flou redondant + iGPU sollicité inutilement).
            blur {
                enabled = false
            }
        }

        animations {
            enabled = true
            bezier = myBezier, 0.05, 0.9, 0.1, 1.05
            animation = windows, 1, 6, myBezier
            animation = fade, 1, 6, default
            animation = workspaces, 1, 5, default
        }

        dwindle {
            preserve_split = true
        }

        ###################
        ### HYPRGLASS   ###
        ###################
        # Effet liquid glass, thème sombre. Format .conf (déprécié mais
        # supporté en 0.55.4) car la config Hyprland ici est en .conf, pas en Lua.
        plugin:hyprglass {
            enabled = true
            default_theme = dark
            default_preset = clear
            # Teinte dérivée de la palette Stylix (accent base0D) → cohérent
            # avec le thème généré depuis le wallpaper.
            tint_color = ${glassTint}
            blur_strength = 2.5
            blur_iterations = 3
            refraction_strength = 0.6
            chromatic_aberration = 0.4
            fresnel_strength = 0.6
            specular_strength = 0.8
            lens_distortion = 0.5
            # Réglages spécifiques au thème sombre
            dark:brightness = 0.82
            dark:contrast = 0.90
            dark:saturation = 0.80
            dark:vibrancy = 0.15
            dark:adaptive_dim = 0.4
            # Appliquer l'effet aux surfaces de calques (ex. waybar)
            layers:enabled = 1
        }

        # (L'opacité des fenêtres est gérée globalement dans decoration ci-dessus.)

        ###################
        ###  RACCOURCIS ###
        ###################
        $mainMod = SUPER
        $term = ${term}

        bind = $mainMod, Return, exec, $term
        bind = $mainMod, Q, killactive,
        bind = $mainMod, M, exit,
        bind = $mainMod, E, exec, nautilus
        bind = $mainMod, V, togglefloating,
        bind = $mainMod, D, exec, rofi -show drun
        # Historique presse-papier via rofi (cliphist)
        bind = $mainMod SHIFT, V, exec, ${pkgs.cliphist}/bin/cliphist list | ${pkgs.rofi}/bin/rofi -dmenu | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy
        bind = $mainMod, P, pseudo,
        bind = $mainMod, J, layoutmsg, togglesplit
        bind = $mainMod, F, fullscreen,

        # Déplacer le focus (flèches + ZQSD pour AZERTY)
        bind = $mainMod, left,  movefocus, l
        bind = $mainMod, right, movefocus, r
        bind = $mainMod, up,    movefocus, u
        bind = $mainMod, down,  movefocus, d

        # Workspaces — keycodes physiques (10..19 = touches 1..0),
        # robuste en AZERTY où les chiffres demandent Shift.
        bind = $mainMod, code:10, workspace, 1
        bind = $mainMod, code:11, workspace, 2
        bind = $mainMod, code:12, workspace, 3
        bind = $mainMod, code:13, workspace, 4
        bind = $mainMod, code:14, workspace, 5
        bind = $mainMod, code:15, workspace, 6
        bind = $mainMod, code:16, workspace, 7
        bind = $mainMod, code:17, workspace, 8
        bind = $mainMod, code:18, workspace, 9
        bind = $mainMod, code:19, workspace, 10

        # Envoyer la fenêtre vers un workspace
        bind = $mainMod SHIFT, code:10, movetoworkspace, 1
        bind = $mainMod SHIFT, code:11, movetoworkspace, 2
        bind = $mainMod SHIFT, code:12, movetoworkspace, 3
        bind = $mainMod SHIFT, code:13, movetoworkspace, 4
        bind = $mainMod SHIFT, code:14, movetoworkspace, 5
        bind = $mainMod SHIFT, code:15, movetoworkspace, 6
        bind = $mainMod SHIFT, code:16, movetoworkspace, 7
        bind = $mainMod SHIFT, code:17, movetoworkspace, 8
        bind = $mainMod SHIFT, code:18, movetoworkspace, 9
        bind = $mainMod SHIFT, code:19, movetoworkspace, 10

        # Déplacer/redimensionner à la souris
        bindm = $mainMod, mouse:272, movewindow
        bindm = $mainMod, mouse:273, resizewindow

        # Captures d'écran
        bind = , Print, exec, grim - | wl-copy
        bind = SHIFT, Print, exec, grim -g "$(slurp)" - | wl-copy

        # Multimédia / luminosité
        binde = , XF86AudioRaiseVolume, exec, pamixer -i 5
        binde = , XF86AudioLowerVolume, exec, pamixer -d 5
        bind  = , XF86AudioMute, exec, pamixer -t
        binde = , XF86MonBrightnessUp, exec, brightnessctl set +5%
        binde = , XF86MonBrightnessDown, exec, brightnessctl set 5%-
      '';
    };
  };
}
