# ─────────────────────────────────────────────────────────────────────────────
# Humanix · Splash de boot Plymouth (phosphore vert)
# ─────────────────────────────────────────────────────────────────────────────
# POURQUOI : le boot est le 1er plan « cinéma ». Logo HUMANIX vert + barre de
# progression + ligne de statut, sur fond noir. Pas de spinner générique.
#
# Risque boot : FAIBLE. Si le thème plymouth échoue, le système démarre en mode
# texte (jamais bloquant). Débrayable via humanix.aesthetic.plymouth.enable.
{ lib, config, pkgs, ... }:
let
  cfg = config.humanix.aesthetic.plymouth;

  # Thème vert bâti sur le moteur two-step (PROUVÉ au diagnostic spinner) : on
  # recolore les assets stock du spinner en vert phosphore + un logo HUMANIX en
  # watermark. Fini le plugin `script` (c'était LUI le bug de rendu, pas le HW).
  humanixThemePkg = pkgs.runCommand "humanix-plymouth"
    { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    sp=${pkgs.plymouth}/share/plymouth/themes/spinner
    d=$out/share/plymouth/themes/humanix
    mkdir -p $d

    # Spinner (throbber + animation) : gris -> vert phosphore, alpha (forme) gardé.
    for f in "$sp"/throbber-*.png "$sp"/animation-*.png; do
      magick "$f" -channel RGB -fill '#00ff41' -colorize 100 +channel "$d/$(basename "$f")"
    done
    # Prompt passphrase : champ + icônes teintés par luminance (structure gardée).
    magick "$sp/entry.png"  -fill '#00b32d' -tint 90  "$d/entry.png"
    magick "$sp/lock.png"   -fill '#00ff41' -tint 100 "$d/lock.png"
    magick "$sp/bullet.png" -channel RGB -fill '#39ff14' -colorize 100 +channel "$d/bullet.png"
    for x in capslock keyboard keymap-render; do
      [ -f "$sp/$x.png" ] && magick "$sp/$x.png" -fill '#00ff41' -tint 100 "$d/$x.png"
    done

    # Logo HUMANIX vert + glow (Victor Mono Bold) -> watermark.png (two-step).
    FONT=$(find ${pkgs.nerd-fonts.victor-mono} -name 'VictorMonoNerdFont-Bold.ttf' | head -1)
    magick -size 900x150 xc:none -font "$FONT" -pointsize 96 -fill '#00ff41' \
      -gravity center -annotate 0 'HUMANIX' \
      \( +clone -blur 0x10 \) -compose screen -composite "$d/watermark.png"

    cp ${./plymouth/humanix.plymouth} $d/humanix.plymouth
    substituteInPlace $d/humanix.plymouth --replace '@THEMEDIR@' "$d"
  '';
in {
  options.humanix.aesthetic.plymouth = {
    enable = lib.mkEnableOption
      "le splash de boot Plymouth Humanix (phosphore vert). Échec = boot texte, jamais bloquant.";

    # Sélecteur de thème = levier de DIAGNOSTIC (isole thème custom vs pipeline
    # DRM). "humanix" = custom vert (plugin script). Un thème STOCK ("spinner",
    # "bgrt", "fade-in", "glow"…) vient du paquet plymouth (plugin two-step C) :
    # s'il rend alors que "humanix" ne rendait pas -> c'était le thème custom.
    theme = lib.mkOption {
      type = lib.types.str;
      default = "humanix";
      example = "spinner";
      description = "Thème plymouth : \"humanix\" (custom vert) ou un thème stock pour diagnostiquer le rendu.";
    };
  };

  config = lib.mkMerge [
    # Humanix pilote la politique plymouth : JAMAIS celui de Stylix. (Sinon,
    # toggle off => Stylix réactive SON plymouth => prompt LUKS re-masqué.)
    { stylix.targets.plymouth.enable = false; }

    (lib.mkIf cfg.enable {
    boot.plymouth = {
      enable = true;
      theme = cfg.theme;
      # themePackages seulement pour le thème custom ; les stock sont dans plymouth.
      themePackages = lib.optionals (cfg.theme == "humanix") [ humanixThemePkg ];
    };

    # CRITIQUE (disque LUKS) : sans initrd systemd, Plymouth ne tourne pas en
    # stage 1 -> le splash + le prompt de passphrase ne s'affichent pas (boot
    # figé, ESC requis). L'initrd systemd lance plymouthd tôt et branche
    # systemd-ask-password sur Plymouth. C'est LA recette fiable plymouth+LUKS.
    boot.initrd.systemd.enable = true;
    # PAS de "quiet" : sur ce combo AMD+LUKS, si Plymouth n'arrive pas à rendre,
    # on veut que le prompt de passphrase reste VISIBLE en texte (fini l'ESC).
    # Bonus : le défilement des logs noyau colle à l'esthétique "faux dmesg" du
    # brief. "splash" garde Plymouth actif s'il rend bien (logo HUMANIX).
    boot.kernelParams = [ "splash" ];
    boot.consoleLogLevel = 4;
    })
  ];
}
