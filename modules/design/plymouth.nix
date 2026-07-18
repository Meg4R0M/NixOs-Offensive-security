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

  humanixThemePkg = pkgs.runCommand "humanix-plymouth" { } ''
    d=$out/share/plymouth/themes/humanix
    mkdir -p $d
    cp ${./plymouth/humanix.script} $d/humanix.script
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
