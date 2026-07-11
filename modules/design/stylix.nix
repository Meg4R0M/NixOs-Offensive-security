{ lib, pkgs, config, inputs, ... }:
let
  cfg = config.athena;

  # Stylix vient du flake : inputs.stylix (cf flake.nix + imports ci-dessous).

  # Wallpaper local (dans le repo). La palette est figée ci-dessous
  # (base16Scheme) donc l'image ne sert QUE de fond d'écran, pas de source
  # de couleurs -> on garde la palette cyberpunk actuelle.
  wallpaper = ../../wallpapers/athena-linus-richard.png;

  # Couleur du jeu d'icônes Tela-circle (mapping Nix-Relic pour Cyberpunk).
  iconColour = "yellow";
in
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  options.athena.useStylix =
    lib.mkEnableOption "Theming global via Stylix (palette auto générée depuis le wallpaper, façon Nix-Relic)";

  config = lib.mkIf cfg.useStylix {
    stylix = {
      enable = true;
      autoEnable = true;
      polarity = "dark";
      image = wallpaper;

      # Palette FIGÉE (cyberpunk dérivée à l'origine du wallpaper Cyberpunk).
      # Découplée de l'image ci-dessus : changer de wallpaper ne change plus
      # les couleurs.
      base16Scheme = {
        base00 = "141839"; base01 = "4d3987"; base02 = "835d81"; base03 = "66a0ec";
        base04 = "e0ad95"; base05 = "e9def5"; base06 = "f3effa"; base07 = "ffeaff";
        base08 = "7987f6"; base09 = "b880a1"; base0A = "ac8784"; base0B = "649d71";
        base0C = "839594"; base0D = "af8a58"; base0E = "bc71df"; base0F = "8d8fa8";
      };

      # Propage automatiquement le thème à tous les users home-manager.
      homeManagerIntegration = {
        autoImport = true;
        followSystem = true;
      };

      icons = {
        enable = true;
        package = pkgs.tela-circle-icon-theme.override {
          colorVariants = [ iconColour ];
        };
        dark = "Tela-circle-${iconColour}";
        light = "Tela-circle-${iconColour}";
      };

      cursor = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
        size = 24;
      };

      fonts = {
        monospace = {
          package = pkgs.nerd-fonts.jetbrains-mono;
          name = "JetBrainsMono Nerd Font Mono";
        };
        serif = {
          package = pkgs.nerd-fonts.noto;
          name = "Noto Serif Nerd Font";
        };
        sansSerif = {
          package = pkgs.nerd-fonts.noto;
          name = "Noto Sans Nerd Font";
        };
        emoji = {
          package = pkgs.noto-fonts-color-emoji;
          name = "Noto Color Emoji";
        };
        sizes = {
          applications = 11;
          terminal = 11;
          desktop = 12;
          popups = 10;
        };
      };
    };

    # On laisse ces apps (rice) être thémées manuellement avec les couleurs
    # Stylix (phases suivantes), comme le fait Nix-Relic. Évite que le target
    # Stylix entre en conflit avec les configs dédiées (Athena/rice).
    home-manager.users.${cfg.homeManagerUser} = {
      stylix.targets = {
        dunst.enable = false;
        rofi.enable = false;
        waybar.enable = false;
        hyprland.enable = false;
        # vscode/vscodium est déjà configuré par Athena (modules/dev/vscodium).
        vscode.enable = false;
        vscodium.enable = false;
        # zellij : thème vert Mr Robot fixe (défini dans le module zsh).
        zellij.enable = false;
        # Qt sous GNOME est géré par la plateforme (adwaita) ; Stylix ne sait
        # pas thémer le platform "gnome" -> on désactive pour couper le warning.
        qt.enable = false;
      };
      # Le nouveau HM veut un enable explicite pour le curseur (Stylix le pose).
      home.pointerCursor.enable = true;
    };
  };
}
