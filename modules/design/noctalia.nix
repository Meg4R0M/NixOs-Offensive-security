# ─────────────────────────────────────────────────────────────────────────────
# Humanix · Noctalia — shell Wayland natif complet, thémé vert
# ─────────────────────────────────────────────────────────────────────────────
# https://github.com/noctalia-dev/noctalia (v5) — barre, dock, launcher, control
# center, notifs+historique, presse-papier, OSD, lock, wallpaper, tray, widgets.
# Natif Wayland/OpenGL (ni Qt ni GTK), config TOML + GUI de réglages, niri natif.
# REMPLACE cshell. Thème via palette custom (rôles Material) = notre vert Mr Robot.
#
# Débrayable : humanix.aesthetic.noctalia.enable (défaut true). Quand actif, niri
# lance Noctalia à la place de cshell/waybar (cf home-manager/desktops/niri).
{ lib, pkgs, config, inputs, ... }:
let
  cfg = config.humanix.aesthetic.noctalia;
  user = config.humanix.homeManagerUser;

  # Paquet Noctalia v5, tests DÉSACTIVÉS : à ce rev, un test upstream
  # (config_schema_roundtrip_test) accède à une méthode privée -> échec de compil.
  # Le binaire principal, lui, compile. `-Dtests=disabled` (option meson feature).
  noctaliaPkg = inputs.noctalia.packages.${pkgs.system}.default.overrideAttrs (o: {
    mesonFlags = (o.mesonFlags or [ ]) ++ [ "-Dtests=disabled" ];
  });

  # Palette verte phosphore Mr Robot, mappée sur les rôles Material de Noctalia.
  green = {
    primary          = "#00ff41";  # accent principal (vert phosphore)
    onPrimary        = "#0a0f0a";  # texte/icône sur primary
    secondary        = "#00cc33";
    onSecondary      = "#0a0f0a";
    tertiary         = "#00d38a";  # teal-vert
    onTertiary       = "#0a0f0a";
    error            = "#ff2b2b";  # rouge (seule touche non-verte)
    onError          = "#0a0f0a";
    surface          = "#0a0f0a";  # fond
    onSurface        = "#00ff41";  # texte principal
    surfaceVariant   = "#0d160d";  # panneaux/cartes
    onSurfaceVariant = "#00cc33";  # texte secondaire
    outline          = "#1f4d1f";  # bordures
    shadow           = "#000000";
    hover            = "#123312";  # survol
    onHover          = "#00ff41";
  };
in {
  options.humanix.aesthetic.noctalia.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Shell Noctalia thémé vert (barre/control center/launcher/…) à la place de cshell.";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      imports = [ inputs.noctalia.homeModules.default ];

      programs.noctalia = {
        enable = true;
        # Lancé par niri (spawn-at-startup), pas par un service systemd (évite la
        # dépendance à la wayland.systemd.target sous niri).
        systemd.enable = false;
        package = noctaliaPkg;

        # settings -> ~/.config/noctalia/config.toml (validé au build). Le gros de
        # la conf (widgets de barre, dock…) se règle ensuite dans la GUI Noctalia.
        settings = {
          theme = {
            mode = "dark";
            # Palette générée DEPUIS le wallpaper vert (mécanisme natif Noctalia,
            # robuste). NB : source="custom" exige le format M3 communautaire
            # (tokens on_primary/surface_variant… snake_case) -> à revoir si on
            # veut le #00ff41 pile. "vibrant" = vert le plus saturé.
            source = "wallpaper";
            wallpaper_scheme = "vibrant";
            pure_black_dark = true;
          };
          # Wallpaper géré par Noctalia (sa couche passait par-dessus swaybg) :
          # on lui donne TON image, en résolution native (center = 1:1).
          wallpaper = {
            enabled = true;
            fill_mode = "center";
            default.path =
              "/home/${user}/Images/wallpappers/black-terminals-with-green-font-colors-quote-6g-2880x1800.jpg";
          };
        };
      };
    };
  };
}
