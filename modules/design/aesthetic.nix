{ lib, config, ... }:
let
  cfg = config.humanix.aesthetic;

  # Bannière console (profil showtime). Rendu en vert via la palette vconsole
  # Stylix — pas d'ANSI codé en dur.
  banner = ''

       __ __  ____ ___  ___ ___  ____  ____  ____ __ __
      / // / / / //   |/   |   |/    ||    ||    |\ \ / /
     / _  / / / // /| / /| / /|_/ / | | |  |  _|  | \ V /
    /_//_/ \___//_/ |/_/ |/_/  /_/|_| |_|_| |_|___| /_/

    >> Make Hacker Cool Again — reste affûté.

  '';
in
{
  options.humanix.aesthetic.profile = lib.mkOption {
    type = lib.types.enum [ "showtime" "work" "client" ];
    default = "work";
    description = ''
      Profil d'ambiance esthétique (préréglages débrayables). Chaque effet
      individuel reste surchargeable (les valeurs ci-dessous sont en mkDefault) :
        - showtime : spectacle maximal (wallpaper animé + bannière MOTD).
                     Démos, conférences, streaming.
        - work     : quotidien équilibré (wallpaper animé, MOTD court).
        - client   : sobre et discret (wallpaper statique, MOTD minimal).
                     À utiliser devant un client / en clientèle.
    '';
  };

  # Barre supérieure niri : cshell (shell Quickshell re-thémé vert phosphore) au
  # lieu de waybar. Débrayable => repli waybar immédiat en cas de souci (aucun
  # risque boot, c'est du user-space). cf home-manager/desktops/niri/default.nix.
  options.humanix.aesthetic.cshell.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Utiliser cshell (Quickshell, thémé vert) comme barre niri au lieu de waybar.";
  };

  # niri-glass : remplace le binaire niri par le fork « liquid glass » (fork Rust,
  # zaroutt/Niri-glass, niri 26.04). Débrayable => repli niri standard. Le bloc de
  # conf glass n'est injecté dans le KDL QUE si ce toggle est ON (le node liquid-glass
  # n'existe pas dans niri standard, il ferait planter le parse). Sessions GNOME/
  # Hyprland en repli au login si le fork pose souci. cf niri/default.nix.
  options.humanix.aesthetic.niriGlass.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Utiliser le fork niri-glass (effet verre dépoli) à la place de niri standard.";
  };

  config = {
    # Wallpaper animé (niri lit humanix.animatedWallpaper) : ON sauf en client.
    humanix.animatedWallpaper = lib.mkDefault (cfg.profile != "client");

    # Message du jour (console/SSH) selon le profil.
    users.motd = lib.mkDefault (
      if cfg.profile == "showtime" then banner
      else if cfg.profile == "work" then "Humanix — reste affûté.\n"
      else "" # client : sobre
    );
  };
}
