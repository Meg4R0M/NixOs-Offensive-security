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
    # glpaper matche l'output par nom EXACT (strcmp). swaymsg -t get_outputs
    # renvoie du JSON PRETTY (espaces après ':' + retours ligne) MÊME avec -r ->
    # un grep '"name":"..."' échoue. Parser sed tolérant aux espaces à la place.
    name=""
    i=0
    while [ "$i" -lt 100 ]; do
      name=$(${pkgs.sway}/bin/swaymsg -t get_outputs -r 2>/dev/null \
        | ${pkgs.gnused}/bin/sed -nE 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' \
        | ${pkgs.coreutils}/bin/head -1)
      [ -n "$name" ] && break
      ${pkgs.coreutils}/bin/sleep 0.1
      i=$((i + 1))
    done
    # Aucun output détecté -> ne PAS lancer glpaper avec un nom bidon.
    [ -z "$name" ] && exit 0

    # Résolution du MODE COURANT -> passée à glpaper (-W/-H) pour un rendu à la
    # def native EXACTE (belt-and-suspenders avec `output * scale 1` côté sway ;
    # évite tout flou/basse def si un scale se glissait). Repli = def par défaut
    # de glpaper (mode natif) si le parse échoue.
    json=$(${pkgs.sway}/bin/swaymsg -t get_outputs -r 2>/dev/null)
    w=$(printf '%s' "$json" | ${pkgs.gnugrep}/bin/grep -A2 '"current_mode"' \
      | ${pkgs.gnugrep}/bin/grep -oE '"width": *[0-9]+' | ${pkgs.gnugrep}/bin/grep -oE '[0-9]+' | ${pkgs.coreutils}/bin/head -1)
    h=$(printf '%s' "$json" | ${pkgs.gnugrep}/bin/grep -A2 '"current_mode"' \
      | ${pkgs.gnugrep}/bin/grep -oE '"height": *[0-9]+' | ${pkgs.gnugrep}/bin/grep -oE '[0-9]+' | ${pkgs.coreutils}/bin/head -1)
    wh=""
    if [ -n "$w" ] && [ -n "$h" ] && [ "$w" -gt 0 ] 2>/dev/null && [ "$h" -gt 0 ] 2>/dev/null; then
      wh="-W $w -H $h"
    fi
    exec ${pkgs.glpaper}/bin/glpaper $wh -f ${toString crack.fps} "$name" ${shaderFile}
  '';

  # Chiptune en boucle. Lecteur auto-détecté : xmp pour les modules tracker
  # (.mod/.xm/.it…), mpv pour le reste (.mp3/.ogg/.flac). Best-effort — si pas
  # de sortie audio (device occupé/absent) le lecteur sort, le visuel continue.
  # Inerte si aucun morceau n'est défini.
  crackMusic = pkgs.writeShellScript "cracktro-music" ''
    ${lib.optionalString (crack.music != null) ''
      case "${crack.music}" in
        *.mod|*.MOD|*.xm|*.XM|*.it|*.IT|*.s3m|*.S3M|*.med|*.MED|*.mtm|*.669|*.far|*.stm|*.okt)
          exec ${pkgs.xmp}/bin/xmp --loop ${crack.music} >/dev/null 2>&1 ;;
        *)
          exec ${pkgs.mpv}/bin/mpv --no-video --loop-file=inf --volume=75 \
            --no-terminal ${crack.music} >/dev/null 2>&1 ;;
      esac
    ''}
    exit 0
  '';

  # Sortie propre du greeter : COUPE glpaper + le lecteur audio (sinon ils
  # survivent à sway -> le son tourne en boucle dans niri après login), puis
  # quitte sway. pkill -f <chemin> = précis (le chemin est dans l'argv) et
  # robuste à un nom de process wrappé.
  crackExit = pkgs.writeShellScript "cracktro-exit" ''
    ${pkgs.procps}/bin/pkill -f ${shaderFile} 2>/dev/null || true
    ${lib.optionalString (crack.music != null)
      "${pkgs.procps}/bin/pkill -f ${crack.music} 2>/dev/null || true"}
    ${pkgs.sway}/bin/swaymsg exit
  '';

  # Session sway du greeter : clavier FR, écran natif (scale 1 comme niri), fond
  # noir, cracktro en calque background, gtkgreet en layer-shell par-dessus. À la
  # fin de gtkgreet -> crackExit (coupe fond+son puis quitte sway = lance session).
  swayCfg = pkgs.writeText "cracktro-sway.conf" ''
    # Clavier FR (azerty, variant oss) = même dispo que niri / console.
    input "type:keyboard" xkb_layout "fr"
    input "type:keyboard" xkb_variant "oss"

    # Scale 1.0 comme niri -> def native (pas de sur-échantillonnage/flou).
    output * bg #000000 solid_color
    output * scale 1

    default_border none
    seat * hide_cursor 6000
    xwayland disable

    exec ${crackBg}
    exec ${crackMusic}
    exec "${pkgs.gtkgreet}/bin/gtkgreet -l -c niri-session -s ${cssFile}; ${crackExit}"

    # Échappatoire clavier (au pire Ctrl+Alt+F2 -> TTY texte reste dispo).
    bindsym Mod4+Shift+q exec ${crackExit}
  '';

  # --unsupported-gpu : laisse sway démarrer sur llvmpipe (VM de test) ; no-op sur
  # le vrai GPU amdgpu (relâche seulement le garde-fou « GPU non supporté »).
  crackCommand = "${pkgs.sway}/bin/sway --unsupported-gpu --config ${swayCfg}";
in
{
  options.humanix.login.cracktro = {
    enable = lib.mkEnableOption "Login cracktro demoscene (sway + glpaper + gtkgreet + chiptune MOD)";

    music = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = ./cracktro/a-night-of-dizzy-spells.mp3;
      example = lib.literalExpression "./assets/tune.mod";
      description = ''
        Morceau joué en boucle au login. Lecteur auto-détecté : xmp pour un
        module tracker (.mod/.xm/.it/.s3m…), mpv pour l'audio (.mp3/.ogg/.flac).
        null = pas de musique. Défaut = « A Night Of Dizzy Spells » d'Eric Skiff
        (Resistor Anthems, CC-BY, cf cracktro/MUSIC-NOTICE.md).
      '';
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
      ++ lib.optionals crack.enable [ pkgs.sway pkgs.glpaper pkgs.gtkgreet pkgs.xmp pkgs.mpv ];

    # L'user greeter a besoin du GPU (glpaper) et de l'audio (xmp) en mode cracktro.
    users.users.greeter.extraGroups = lib.mkIf crack.enable [ "video" "render" "audio" "input" ];

    # Filet : on s'assure qu'aucun autre DM ne tente de démarrer en parallèle.
    services.displayManager.sddm.enable = lib.mkForce false;
    services.displayManager.gdm.enable = lib.mkForce false;

    # greetd tourne sur la VT1 ; on garde une VT texte libre pour le rattrapage.
    # (Si le login graphique casse, Ctrl+Alt+F2 -> shell root reste possible.)
  };
}
