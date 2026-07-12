# Humanix · Profil de durcissement (opt-in) — repris de RedNixOS/tangerinixos.
# Débrayable : humanix.hardening.enable (défaut OFF, choix conscient sur une
# station offensive) + sous-option hostsBlocklist.
{ lib, config, ... }:
let
  cfg = config.humanix.hardening;
  inherit (lib) mkEnableOption mkIf mkMerge mkDefault;
in {
  options.humanix.hardening = {
    enable = mkEnableOption
      "durcissement système (SSH publickey-only, sudo wheel-only, auditd, nix @wheel)";
    hostsBlocklist.enable = mkEnableOption
      "blocage DNS pub/malware via StevenBlack/hosts (paquet nixpkgs pinné)";
  };

  config = mkMerge [
    (mkIf cfg.enable {
      # SSH : clé publique uniquement, pas de root (ne s'applique que si openssh actif).
      services.openssh.settings = {
        PasswordAuthentication = mkDefault false;
        KbdInteractiveAuthentication = mkDefault false;
        PermitRootLogin = mkDefault "no";
      };
      # sudo réservé au groupe wheel ; nix-daemon réservé à wheel.
      security.sudo.execWheelOnly = mkDefault true;
      nix.settings.allowed-users = mkDefault [ "@wheel" ];
      # Journal d'audit (exécutions de binaires).
      security.auditd.enable = mkDefault true;
      security.audit = {
        enable = mkDefault true;
        rules = mkDefault [ "-a exit,always -F arch=b64 -S execve -k humanix-exec" ];
      };
    })
    (mkIf cfg.hostsBlocklist.enable {
      networking.stevenblack = {
        enable = true;
        block = [ "fakenews" "gambling" ];
      };
    })
  ];
}
