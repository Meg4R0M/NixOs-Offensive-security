# ─────────────────────────────────────────────────────────────────────────────
# Humanix · Arsenal "plus" — compléments modernes des 12 rôles Athena
# ─────────────────────────────────────────────────────────────────────────────
# Outils tirés de l'analyse de 4 configs offensives NixOS de référence
# (fabaff/nix-security-box, redcode-labs/RedNix, MasterofNull/maxos,
# Pamplemousse/tangerinixos), filtrés pour ne garder que ce qui MANQUE à Athena
# (59 paquets, tous vérifiés présents dans le nixpkgs pinné).
#
# Angles neufs vs Athena : Active Directory moderne (ADCS/coercition), offensive
# CLOUD/K8s/CI-CD (le plus gros différenciateur), DFIR Windows, RF/NFC/CAN bus.
# Tout est DÉBRAYABLE par catégorie (humanix.arsenal.<cat>.enable).
{ lib, pkgs, config, inputs, ... }:
let
  cfg = config.humanix.arsenal;
  inherit (lib) mkIf mkOption types optionals mkMerge;
  cat = desc: mkOption { type = types.bool; default = true; description = desc; };
in {
  options.humanix.arsenal = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Arsenal 'plus' Humanix (compléments modernes des rôles Athena).";
    };
    ad.enable        = cat "Active Directory moderne (ADCS, coercition, LDAP).";
    recon.enable     = cat "Recon/DNS complémentaire (ProjectDiscovery & co).";
    cloud.enable     = cat "Offensive cloud / Kubernetes / CI-CD / supply-chain.";
    forensic.enable  = cat "DFIR / forensic Windows complémentaire.";
    reversing.enable = cat "Reverse / malware analysis moderne.";
    pivot.enable     = cat "Pivot / tunneling complémentaire.";
    osint.enable     = cat "OSINT complémentaire.";
    rf.enable        = cat "RF / sans-fil / NFC / CAN bus (bidouille hardware).";
    misc.enable      = cat "Couteaux suisses & prise de notes (cyberchef, navi…).";
    rcl.enable       = cat "Outils maison redcode-labs (gosh, godspeed, snowcrash, sammler).";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      environment.systemPackages = with pkgs; (
        # ── Active Directory moderne (chaîne post-Impacket) ──────────────────
        optionals cfg.ad.enable [
          adidnsdump    # dump des zones DNS intégrées à l'AD
          autobloody    # exploitation auto de chemins BloodHound
          donpapi       # collecte de secrets en masse (DPAPI)
          # hekatomb    # build KO sur ce nixpkgs (dépendance python)
          keepwn        # attaques KeePass en environnement AD
          ldapnomnom    # énumération AD ultra-rapide (guessing)
          pywhisker     # shadow credentials (msDS-KeyCredentialLink)
          sccmhunter    # attaques SCCM / MECM
        ]
        # ── Recon / DNS (compléments ProjectDiscovery & co) ─────────────────
        ++ optionals cfg.recon.enable [
          cdncheck findomain massdns puredns tlsx waybackurls
        ]
        # ── Offensive CLOUD / K8s / CI-CD / supply-chain (gros gap Athena) ───
        ++ optionals cfg.cloud.enable [
          pacu          # framework d'exploitation AWS
          cloudfox      # recon offensif multi-cloud
          goblob        # énumération de blobs Azure
          gato          # attaque GitHub Actions / CI-CD
          gitjacker     # dump de dossiers .git exposés
          kubescape kubeaudit kdigger kubestroyer peirates # K8s (kube-hunter: build KO)
          cdk-go        # container escape toolkit
          grype dockle  # scan de vulnérabilités d'images
          noseyparker   # détection de secrets à grande échelle
          osv-scanner semgrep # vulnérabilités connues / SAST
        ]
        # ── DFIR / forensic Windows ─────────────────────────────────────────
        ++ optionals cfg.forensic.enable [
          hivex         # lecture/édition de ruches de registre Windows
          nwipe         # effacement sécurisé de disque
          stegseek      # crack steghide ultra-rapide
        ]
        # ── Reverse / malware analysis moderne ──────────────────────────────
        ++ optionals cfg.reversing.enable [
          capa          # détection de capacités de binaires (FLARE)
          yara-x        # nouveau moteur YARA (Rust)
          imhex rehex   # éditeurs hexa pour reversers
          gef           # GDB Enhanced Features (exploit dev)
        ]
        # ── Pivot / tunneling ───────────────────────────────────────────────
        ++ optionals cfg.pivot.enable [ sish wireproxy ]
        # ── OSINT ───────────────────────────────────────────────────────────
        ++ optionals cfg.osint.enable [
          ghunt h8mail maigret recon-ng wtfis # (sherlock: build KO python)
        ]
        # ── RF / sans-fil / NFC / CAN bus / IoT ─────────────────────────────
        ++ optionals cfg.rf.enable [
          ubertooth     # Bluetooth (BLE) sniffing (host tools)
          killerbee     # attaque ZigBee / 802.15.4
          reaverwps     # attaque WPS
          libnfc        # NFC (lecteurs génériques)
          gallia        # pentest automobile (CAN / UDS)
          can-utils     # outils bus CAN (candump, cansend…)
        ]
        # ── Couteaux suisses & notes ────────────────────────────────────────
        ++ optionals cfg.misc.enable [
          cyberchef     # « couteau suisse » data (offline)
          navi arsenal  # cheatsheets de commandes interactifs
          nth ares      # name-that-hash + ares (déchiffrement auto)
          cherrytree    # prise de notes hiérarchique (pentest)
        ]
        # ── Outils maison redcode-labs (hors nixpkgs, via input flake) ──────
        ++ optionals cfg.rcl.enable (
          let p = inputs.rednix.packages.${pkgs.system}; in [
            p.gosh        # générateur de reverse/bind shells (Go)
            p.godspeed    # gestionnaire multi-reverse-shells
            p.snowcrash   # générateur de payloads polyglottes
            p.sammler     # extraction de données utiles (OSINT/loot)
          ]
        )
      );
    }
    # ubertooth fournit ses propres règles udev (accès BLE sans root).
    (mkIf cfg.rf.enable { services.udev.packages = [ pkgs.ubertooth ]; })
  ]);
}
