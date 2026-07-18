# ─────────────────────────────────────────────────────────────────────────────
# Humanix · Login « console » — greetd + tuigreet  (+ mode CRACKTRO opt-in)
# ─────────────────────────────────────────────────────────────────────────────
# POURQUOI : le login est le 1er contact avec la machine. Le brief veut une
# ambiance CONSOLE 100 % terminal (pas un DM graphique générique) : phosphore
# vert, sessions listées comme un menu d'intrusion, greeting « accès restreint ».
#
# Débrayable : activé quand `humanix.displayManager == "greetd"`. Repli SDDM =
# remettre `dmanager = "sddm"` dans configuration.nix (1 ligne).
#
# MODE CRACKTRO (opt-in `humanix.login.cracktro.enable`) : remplace tuigreet par
# une mini-session sway affichant un cracktro Amiga (glpaper + shader GLSL :
# copper bars / plasma / starfield / logo & scroller sinus) avec gtkgreet stylé
# vert par-dessus, + chiptune MOD (xmp) optionnel. tuigreet reste le repli si
# cracktro.enable = false. Ctrl+Alt+F2 -> TTY texte reste l'échappatoire ultime.
{ lib, config, pkgs, ... }:
let
  cfg   = config.humanix;
  crack = cfg.login.cracktro;

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

  # ── CRACKTRO ────────────────────────────────────────────────────────────────
  shaderFile = ./cracktro/cracktro.frag;
  cssFile    = ./cracktro/gtkgreet.css;

  # glpaper matche l'output par nom EXACT (strcmp) : pas de '*'. On interroge sway
  # pour récupérer le 1er output et on le lui passe (jq absent -> grep/cut).
  crackBg = pkgs.writeShellScript "cracktro-bg" ''
    name=""
    i=0
    while [ "$i" -lt 50 ]; do
      name=$(${pkgs.sway}/bin/swaymsg -t get_outputs -r 2>/dev/null \
        | ${pkgs.gnugrep}/bin/grep -o '"name":"[^"]*"' \
        | ${pkgs.coreutils}/bin/head -1 \
        | ${pkgs.coreutils}/bin/cut -d'"' -f4)
      [ -n "$name" ] && break
      ${pkgs.coreutils}/bin/sleep 0.1
      i=$((i + 1))
    done
    [ -z "$name" ] && name="eDP-1"
    exec ${pkgs.glpaper}/bin/glpaper -f ${toString crack.fps} "$name" ${shaderFile}
  '';

  # Chiptune : xmp en boucle sur le module Amiga. Best-effort — si pas de sortie
  # audio (device occupé / absent), xmp sort et le visuel continue. Inerte si
  # aucun module n'est défini.
  crackMusic = pkgs.writeShellScript "cracktro-music" ''
    ${lib.optionalString (crack.module != null) ''
      exec ${pkgs.xmp}/bin/xmp --loop ${crack.module} >/dev/null 2>&1
    ''}
    exit 0
  '';

  # Session sway du greeter : fond noir, cracktro en calque background, gtkgreet
  # en layer-shell par-dessus. sway se ferme quand gtkgreet a fini (login validé).
  swayCfg = pkgs.writeText "cracktro-sway.conf" ''
    exec ${crackBg}
    exec ${crackMusic}
    exec "${pkgs.gtkgreet}/bin/gtkgreet -l -c niri-session -s ${cssFile}; ${pkgs.sway}/bin/swaymsg exit"

    output * bg #000000 solid_color
    default_border none
    seat * hide_cursor 6000
    xwayland disable

    # Échappatoire clavier (au pire Ctrl+Alt+F2 -> TTY texte reste dispo).
    bindsym Mod4+Shift+q exec "${pkgs.sway}/bin/swaymsg exit"
  '';

  # --unsupported-gpu : laisse sway démarrer sur llvmpipe (VM de test) ; no-op sur
  # le vrai GPU amdgpu (relâche seulement le garde-fou « GPU non supporté »).
  crackCommand = "${pkgs.sway}/bin/sway --unsupported-gpu --config ${swayCfg}";
in
{
  options.humanix.login.cracktro = {
    enable = lib.mkEnableOption "Login cracktro demoscene (sway + glpaper + gtkgreet + chiptune MOD)";

    module = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression "./assets/tune.mod";
      description = "Module Amiga (.mod/.xm/.s3m...) joué en boucle au login via xmp. null = pas de musique.";
    };

    fps = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "FPS de rendu du cracktro (glpaper). 30 suffit et ménage la batterie.";
    };
  };

  config = lib.mkIf (cfg.displayManager == "greetd") {
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = if crack.enable then crackCommand else cmd;
          user = "greeter";
        };
      };
    };

    # gtkgreet lit ce fichier pour peupler le menu de sessions.
    environment.etc."greetd/environments" = lib.mkIf crack.enable {
      text = ''
        niri-session
        bash
      '';
    };

    environment.systemPackages = [ pkgs.tuigreet ]
      ++ lib.optionals crack.enable [ pkgs.sway pkgs.glpaper pkgs.gtkgreet pkgs.xmp ];

    # L'user greeter a besoin du GPU (glpaper) et de l'audio (xmp) en mode cracktro.
    users.users.greeter.extraGroups = lib.mkIf crack.enable [ "video" "render" "audio" "input" ];

    # Filet : on s'assure qu'aucun autre DM ne tente de démarrer en parallèle.
    services.displayManager.sddm.enable = lib.mkForce false;
    services.displayManager.gdm.enable = lib.mkForce false;

    # greetd tourne sur la VT1 ; on garde une VT texte libre pour le rattrapage.
    # (Si le login graphique casse, Ctrl+Alt+F2 -> shell root reste possible.)
  };
}
