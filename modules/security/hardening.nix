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

      # Firewall (défaut NixOS = on ; on l'assume explicitement).
      networking.firewall.enable = mkDefault true;

      # Durcissement noyau/réseau par sysctl — CHOISI pour ne PAS casser l'outillage
      # OFFENSIF : on NE touche PAS rp_filter, kernel.yama.ptrace_scope,
      # unprivileged_bpf ni les user namespaces (MITM/spoofing, debug/attach de
      # process, eBPF, sandbox nix/docker/browsers en ont besoin). On durcit
      # seulement ce qui protège la STATION sans la brider.
      boot.kernel.sysctl = {
        # Réseau : ignore redirections ICMP + source-routing (anti-MITM sur l'hôte),
        # loggue les paquets spoofés (martians), anti-smurf, SYN cookies.
        "net.ipv4.conf.all.accept_redirects"     = mkDefault 0;
        "net.ipv6.conf.all.accept_redirects"     = mkDefault 0;
        "net.ipv4.conf.all.send_redirects"       = mkDefault 0;
        "net.ipv4.conf.all.accept_source_route"  = mkDefault 0;
        "net.ipv6.conf.all.accept_source_route"  = mkDefault 0;
        "net.ipv4.conf.all.log_martians"         = mkDefault 1;
        "net.ipv4.icmp_echo_ignore_broadcasts"   = mkDefault 1;
        "net.ipv4.tcp_syncookies"                = mkDefault 1;
        # Noyau : cache dmesg aux non-root + coupe kexec (anti-persistance).
        # (kernel.kptr_restrict=1 est DÉJÀ posé par NixOS -> pas redéfini ici ; si
        # exploit-dev userland le gêne : sysctl."kernel.kptr_restrict" = mkForce 0.)
        "kernel.dmesg_restrict"      = mkDefault 1;
        "kernel.kexec_load_disabled" = mkDefault 1;
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
