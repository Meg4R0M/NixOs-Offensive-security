# ─────────────────────────────────────────────────────────────────────────────
# Humanix · Kernel CachyOS — variante configurable (défaut : lts/BORE)
# ─────────────────────────────────────────────────────────────────────────────
# Via xddxdd/nix-cachyos-kernel (overlay "pinned" = derivations alignées sur le
# cache binaire Attic "lantian", pour éviter la compilation locale = des heures).
#
# ⚠️ BOOT-CRITIQUE. Débrayable via humanix.kernel.cachyos.enable. Repli : au boot,
# menu systemd-boot -> génération précédente (kernel LTS). kernel/default.nix
# garde `boot.kernelPackages = lib.mkDefault linuxPackages` (LTS) qui reprend la
# main dès que ce toggle est off.
#
# ⚠️ CACHE : nix.settings.extra-substituters n'est actif qu'APRÈS un switch. Pour
# le 1er build (celui qui installe ce kernel), il faut passer le cache en ligne
# de commande, en root (seul root est trusted ici) :
#   sudo nixos-rebuild switch -I nixos-config=$HOME/nixos/configuration.nix \
#     --option extra-substituters "https://attic.xuyh0120.win/lantian" \
#     --option extra-trusted-public-keys "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
{ lib, pkgs, config, inputs, ... }:
let
  cfg = config.humanix.kernel.cachyos;

  cachyos = inputs.cachyos; # du flake (expose .overlays.pinned)
in {
  options.humanix.kernel.cachyos = {
    enable = lib.mkEnableOption
      "le kernel CachyOS via xddxdd/nix-cachyos-kernel + cache Attic lantian";
    variant = lib.mkOption {
      type = lib.types.enum [ "lts" "bore" "eevdf" "hardened" ];
      default = "lts";
      description = ''
        Variante CachyOS (attr = linuxPackages-cachyos-<variant>) :
        - "lts"      : base LTS 6.18.x (= base qui boote) + BORE. Le plus sûr.
        - "bore"     : base récente 7.1.x + BORE (même scheduler que lts).
        - "eevdf"    : base récente 7.1.x + EEVDF.
        - "hardened" : durci sécurité, base bleeding-edge 7.0.x (a PANIQUÉ au boot
                       sur ce Ryzen AI 300). À éviter pour l'instant.
        Les variantes 7.x sont plus récentes (support matériel frais) mais plus
        risquées sur un APU neuf ; rollback dispo via systemd-boot.
      '';
    };
  };

  config = lib.mkMerge [
    # L'overlay est toujours présent (il n'évalue le kernel que s'il est
    # référencé -> aucun coût tant que le toggle est off). Évite une récursion
    # nixpkgs.overlays <-> config.
    { nixpkgs.overlays = [ cachyos.overlays.pinned ]; }

    (lib.mkIf cfg.enable {
      boot.kernelPackages = pkgs.cachyosKernels."linuxPackages-cachyos-${cfg.variant}";

      # Le module out-of-tree VMware (kernel/default.nix) casse fréquemment sur
      # un kernel hardened récent ET compilerait en local (hors cache Attic).
      # On le retire ici (la virtualisation passe par KVM, cf modules/hardware/
      # virtualization). À réactiver seulement si VMware Workstation est requis.
      boot.extraModulePackages = lib.mkForce [ ];

      # Deux caches (redondance) : Attic lantian (primaire) + cache.xinux.uz
      # (secours). Les deux ont le kernel ; nix prend celui qui répond.
      nix.settings = {
        extra-substituters = [
          "https://attic.xuyh0120.win/lantian"
          "https://cache.xinux.uz"
        ];
        extra-trusted-public-keys = [
          "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
          "cache.xinux.uz:BXCrtqejFjWzWEB9YuGB7X2MV4ttBur1N8BkwQRdH+0="
        ];
      };
    })
  ];
}
