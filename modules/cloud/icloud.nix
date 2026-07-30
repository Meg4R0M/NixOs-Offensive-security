# ─────────────────────────────────────────────────────────────────────────────
# Humanix · iCloud Drive via rclone (montage FUSE)
# ─────────────────────────────────────────────────────────────────────────────
# Apple ne fournit pas de client Linux ; on monte iCloud Drive comme un dossier
# via le backend `iclouddrive` de rclone (officiel depuis rclone 1.69).
#
# ⚠️ Auth INTERACTIVE, une fois (elle n'est PAS déclarative — le token vit dans
#    ~/.config/rclone/rclone.conf, hors git) :
#      rclone config       # créer un remote nommé "icloud", type iclouddrive
#    - Apple ID + mot de passe NORMAL + 2FA (SRP). PAS de mot de passe app-specific.
#    - Token de confiance valable ~30 j -> `rclone reconnect icloud:` ensuite.
#    - Si ADP (Advanced Data Protection) : activer « Accéder aux données iCloud sur
#      le web » sur un appareil Apple.
#    - Drive = lecture/écriture ; Photos = lecture seule. Backend Tier 4 (exp.).
#
# Le service user ne démarre QUE si rclone.conf existe (ConditionPathExists) ->
# pas de spam avant la config. Après `rclone config` :
#      systemctl --user start rclone-icloud   (ou relog)
{ lib, pkgs, config, ... }:
let
  cfg = config.humanix.cloud.icloud;
  user = config.humanix.homeManagerUser;
in
{
  options.humanix.cloud.icloud = {
    enable = lib.mkEnableOption "montage iCloud Drive via rclone (FUSE, opt-in)";
    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "iCloud";
      description = "Dossier de montage, relatif à $HOME (défaut ~/iCloud).";
    };
    remoteName = lib.mkOption {
      type = lib.types.str;
      default = "icloud";
      description = "Nom du remote rclone (celui créé via `rclone config`).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.rclone ];

    home-manager.users.${user}.systemd.user.services.rclone-icloud = {
      Unit = {
        Description = "iCloud Drive (rclone FUSE)";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
        # Ne démarre pas tant que rclone n'est pas configuré (évite les redémarrages
        # en boucle avant `rclone config`).
        ConditionPathExists = "%h/.config/rclone/rclone.conf";
      };
      Install.WantedBy = [ "default.target" ];
      Service = {
        Type = "notify";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/${cfg.mountPoint}";
        ExecStart = ''
          ${pkgs.rclone}/bin/rclone mount ${cfg.remoteName}: %h/${cfg.mountPoint} \
            --vfs-cache-mode full --dir-cache-time 12h --vfs-cache-max-age 24h \
            --poll-interval 30s --volname iCloud
        '';
        ExecStop = "${pkgs.fuse3}/bin/fusermount3 -u %h/${cfg.mountPoint}";
        Restart = "on-failure";
        RestartSec = 15;
        # rclone appelle fusermount3 (setuid, via /run/wrappers) pour monter.
        Environment = "PATH=/run/wrappers/bin:${lib.makeBinPath [ pkgs.fuse3 ]}";
      };
    };
  };
}
