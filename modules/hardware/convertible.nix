# ─────────────────────────────────────────────────────────────────────────────
# Humanix · 2-en-1 / convertible (HP OmniBook X Flip) — tactile, stylet, rotation
# ─────────────────────────────────────────────────────────────────────────────
# Le tactile (ELAN) et le stylet marchent déjà via libinput sous niri. Ce module
# ajoute : capteur iio (accéléromètre), rotation auto écran+tactile (niri),
# clavier à l'écran (wvkbd) à la demande, et apps stylet (rnote/xournalpp).
# Débrayable : humanix.hardware.convertible.enable. Rien de bloquant au boot.
#
# ⚠️ Ce modèle n'expose PAS de SW_TABLET_MODE ni de 2e accéléromètre → pas de
# détection auto du pliage. Le clavier écran et le verrou de rotation sont donc
# sur raccourcis (Mod+K, Mod+Shift+R), câblés dans la config niri.
{ lib, pkgs, config, ... }:
let
  cfg = config.humanix.hardware.convertible;
  inherit (lib) mkEnableOption mkOption types mkIf optionals;

  # Rotation auto : accéléromètre (monitor-sensor) -> transform de sortie niri.
  # niri remappe automatiquement le tactile/stylet sur la sortie transformée.
  autorotate = pkgs.writeShellScriptBin "humanix-autorotate" ''
    export PATH="${lib.makeBinPath [ pkgs.iio-sensor-proxy pkgs.gnugrep ]}:$PATH"
    OUT="''${1:-eDP-1}"
    ${pkgs.iio-sensor-proxy}/bin/monitor-sensor | while read -r line; do
      case "$line" in
        *"changed: normal"*)    niri msg output "$OUT" transform normal ;;
        *"changed: bottom-up"*) niri msg output "$OUT" transform 180 ;;
        *"changed: left-up"*)   niri msg output "$OUT" transform 90 ;;
        *"changed: right-up"*)  niri msg output "$OUT" transform 270 ;;
      esac
    done
  '';

  # Clavier à l'écran (wvkbd, layer-shell) — bascule affichage/masquage.
  oskToggle = pkgs.writeShellScriptBin "humanix-osk-toggle" ''
    if ${pkgs.procps}/bin/pgrep -x wvkbd-mobintl >/dev/null; then
      ${pkgs.procps}/bin/pkill -x wvkbd-mobintl
    else
      ${pkgs.wvkbd}/bin/wvkbd-mobintl -L 320 --fn "VictorMono Nerd Font 18" &
    fi
  '';

  # Verrou de rotation (coupe/relance la rotation auto).
  rotateToggle = pkgs.writeShellScriptBin "humanix-autorotate-toggle" ''
    if ${pkgs.procps}/bin/pgrep -f 'bin/monitor-sensor' >/dev/null; then
      ${pkgs.procps}/bin/pkill -f 'bin/monitor-sensor' || true
      ${pkgs.libnotify}/bin/notify-send -t 1500 "󰑵 Rotation auto : OFF" 2>/dev/null || true
    else
      ${autorotate}/bin/humanix-autorotate &
      ${pkgs.libnotify}/bin/notify-send -t 1500 "󰑵 Rotation auto : ON" 2>/dev/null || true
    fi
  '';

  # Lanceur .desktop du clavier écran -> visible dans le launcher Noctalia (tactile)
  # et épinglable au dock. Indispensable en mode tablette : le raccourci Mod+K est
  # inutilisable clavier replié (ce modèle n'a pas de SW_TABLET_MODE, cf. plus haut).
  oskDesktop = pkgs.makeDesktopItem {
    name = "humanix-osk";
    desktopName = "Clavier écran";
    comment = "Afficher / masquer le clavier tactile";
    exec = "humanix-osk-toggle";
    icon = "input-keyboard";
    categories = [ "Utility" "Accessibility" ];
    terminal = false;
  };
in {
  options.humanix.hardware.convertible = {
    enable = mkEnableOption "support 2-en-1 (accéléromètre, rotation auto niri, clavier écran, stylet)";
    stylusApps = mkOption {
      type = types.bool;
      default = true;
      description = "Apps stylet : rnote (notes manuscrites) + xournalpp (annotation PDF).";
    };
  };

  config = mkIf cfg.enable {
    # Accéléromètre / capteur de luminosité (D-Bus + monitor-sensor).
    hardware.sensor.iio.enable = true;

    environment.systemPackages = with pkgs; [
      wvkbd                 # clavier à l'écran (layer-shell)
      iio-sensor-proxy      # monitor-sensor (accéléromètre)
      libwacom              # identification/calibration stylet
      autorotate oskToggle rotateToggle oskDesktop
    ] ++ optionals cfg.stylusApps [ rnote xournalpp ];

    # Exposé pour la config niri (spawn + binds), cf home-manager/desktops/niri.
    # (Les scripts sont dans le PATH système → niri les trouve par leur nom.)
  };
}
