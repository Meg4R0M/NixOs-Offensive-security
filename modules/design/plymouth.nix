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

  theme = pkgs.runCommand "humanix-plymouth" { } ''
    d=$out/share/plymouth/themes/humanix
    mkdir -p $d
    cp ${./plymouth/humanix.script} $d/humanix.script
    cp ${./plymouth/humanix.plymouth} $d/humanix.plymouth
    substituteInPlace $d/humanix.plymouth --replace '@THEMEDIR@' "$d"
  '';
in {
  options.humanix.aesthetic.plymouth.enable = lib.mkEnableOption
    "le splash de boot Plymouth Humanix (phosphore vert). Échec = boot texte, jamais bloquant.";

  config = lib.mkIf cfg.enable {
    # Stylix themise aussi plymouth (theme "stylix") -> on lui cède la place.
    stylix.targets.plymouth.enable = false;

    boot.plymouth = {
      enable = true;
      theme = "humanix";
      themePackages = [ theme ];
    };

    # CRITIQUE (disque LUKS) : sans initrd systemd, Plymouth ne tourne pas en
    # stage 1 -> le splash + le prompt de passphrase ne s'affichent pas (boot
    # figé, ESC requis). L'initrd systemd lance plymouthd tôt et branche
    # systemd-ask-password sur Plymouth. C'est LA recette fiable plymouth+LUKS.
    boot.initrd.systemd.enable = true;
    # Boot silencieux pour laisser la scène au splash (l'utilisateur peut
    # retirer "quiet" pour retrouver le dmesg brut s'il préfère).
    boot.kernelParams = [ "quiet" "splash" ];
    boot.consoleLogLevel = 3;
    boot.initrd.verbose = false;
  };
}
