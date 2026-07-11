# ─────────────────────────────────────────────────────────────────────────────
# Humanix · Login « console » — greetd + tuigreet
# ─────────────────────────────────────────────────────────────────────────────
# POURQUOI : le login est le 1er contact avec la machine. Le brief veut une
# ambiance CONSOLE 100 % terminal (pas un DM graphique générique) : phosphore
# vert, sessions listées comme un menu d'intrusion, greeting « accès restreint ».
#
# Débrayable : activé quand `humanix.displayManager == "greetd"`. Repli SDDM =
# remettre `dmanager = "sddm"` dans configuration.nix (1 ligne).
#
# tuigreet lance la session choisie parmi les .desktop enregistrés par
# programs.niri.enable / hyprland / gnome (wayland-sessions + xsessions).
{ lib, config, pkgs, ... }:
let
  tuigreet = "${pkgs.tuigreet}/bin/tuigreet";

  # Dossiers de sessions (Wayland d'abord, X en repli).
  sessions = lib.concatStringsSep ":" [
    "/run/current-system/sw/share/wayland-sessions"
    "/run/current-system/sw/share/xsessions"
  ];

  # Thème couleurs tuigreet : vert phosphore dominant, rouge « armé » sur les
  # actions. Clés : border/text/prompt/time/greet/input/action/button/container.
  theme = lib.concatStringsSep ";" [
    "border=green"
    "text=green"
    "prompt=lightgreen"
    "time=green"
    "greet=lightgreen"
    "input=green"
    "container=black"
    "action=red"
    "button=red"
  ];

  greeting = "[ HUMANIX ]  ACCES RESTREINT  //  systemes autorises uniquement  //  la bidouille est reine";

  cmd = lib.concatStringsSep " " [
    tuigreet
    "--remember"
    "--remember-session"
    "--time"
    "--asterisks"
    "--sessions ${sessions}"
    "--theme '${theme}'"
    "--greeting '${greeting}'"
  ];
in {
  config = lib.mkIf (config.humanix.displayManager == "greetd") {
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = cmd;
          user = "greeter";
        };
      };
    };

    environment.systemPackages = [ pkgs.tuigreet ];

    # Filet : on s'assure qu'aucun autre DM ne tente de démarrer en parallèle.
    services.displayManager.sddm.enable = lib.mkForce false;
    services.displayManager.gdm.enable = lib.mkForce false;

    # greetd tourne sur la VT1 ; on garde une VT texte libre pour le rattrapage.
    # (Si le login graphique casse, Ctrl+Alt+F2 -> shell root reste possible.)
  };
}
