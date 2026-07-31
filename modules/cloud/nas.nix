# ─────────────────────────────────────────────────────────────────────────────
# Humanix · Montage NAS SMB/CIFS — Synology "LinuSploiT-NAS" (192.168.1.11)
# ─────────────────────────────────────────────────────────────────────────────
# Automount À LA DEMANDE : nofail + noauto + x-systemd.automount -> le partage se
# monte quand tu ACCÈDES au dossier, et ne bloque JAMAIS le boot (laptop roaming :
# hors LAN / NAS éteint = pas de gel), démonté après inactivité.
#
# ⚠️ Identifiants PAS en git. Fichier root chmod 600 à créer à la main (une fois) :
#     sudo install -m600 /dev/stdin /etc/nas-credentials <<'EOF'
#     username=<utilisateur DSM>
#     password=<mot de passe DSM>
#     EOF
# (Le partage exige l'auth — invité désactivé côté Synology.)
{ lib, pkgs, config, ... }:
let
  cfg = config.humanix.cloud.nas;
in
{
  options.humanix.cloud.nas = {
    enable = lib.mkEnableOption "montage NAS SMB/CIFS (automount à la demande)";
    host = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.11";
      description = "IP ou hostname du NAS.";
    };
    share = lib.mkOption {
      type = lib.types.str;
      description = "Nom du partage SMB (dossier partagé DSM), ex. \"data\".";
    };
    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/nas";
      description = "Point de montage local.";
    };
    credentialsFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nas-credentials";
      description = "Fichier root 600 (username=/password=), HORS git.";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = config.humanix.homeManagerUser;
      description = "Propriétaire des fichiers montés.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.cifs-utils ];

    fileSystems.${cfg.mountPoint} = {
      device = "//${cfg.host}/${cfg.share}";
      fsType = "cifs";
      options = [
        "credentials=${cfg.credentialsFile}"
        "uid=${cfg.user}"
        "gid=users"
        "file_mode=0664"
        "dir_mode=0775"
        "iocharset=utf8"
        "vers=3.0"
        # roaming-safe : à la demande, jamais bloquant, démonté après 2 min d'inactivité
        "nofail"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=120"
        "x-systemd.mount-timeout=10s"
      ];
    };
  };
}
