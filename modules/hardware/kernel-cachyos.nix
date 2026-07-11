# ─────────────────────────────────────────────────────────────────────────────
# Humanix · Kernel CachyOS — variante HARDENED
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
{ lib, pkgs, config, ... }:
let
  cfg = config.humanix.kernel.cachyos;

  cachyosSrc = builtins.fetchTarball {
    url = "https://github.com/xddxdd/nix-cachyos-kernel/archive/4673c8f6d48baf2ec3f14b6a9f8c4ecfb0810d6f.tar.gz";
    sha256 = "1qphbxgp24n5lysrzg6ivf97db6yx0as0qf5whd7585rbl7hp463";
  };
  cachyos = import cachyosSrc; # flake-compat -> expose .overlays.pinned
in {
  options.humanix.kernel.cachyos.enable = lib.mkEnableOption
    "le kernel CachyOS (variante hardened) via xddxdd/nix-cachyos-kernel + cache Attic lantian";

  config = lib.mkMerge [
    # L'overlay est toujours présent (il n'évalue le kernel que s'il est
    # référencé -> aucun coût tant que le toggle est off). Évite une récursion
    # nixpkgs.overlays <-> config.
    { nixpkgs.overlays = [ cachyos.overlays.pinned ]; }

    (lib.mkIf cfg.enable {
      boot.kernelPackages = pkgs.cachyosKernels."linuxPackages-cachyos-hardened";

      # Le module out-of-tree VMware (kernel/default.nix) casse fréquemment sur
      # un kernel hardened récent ET compilerait en local (hors cache Attic).
      # On le retire ici (la virtualisation passe par KVM, cf modules/hardware/
      # virtualization). À réactiver seulement si VMware Workstation est requis.
      boot.extraModulePackages = lib.mkForce [ ];

      nix.settings = {
        extra-substituters = [ "https://attic.xuyh0120.win/lantian" ];
        extra-trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
      };
    })
  ];
}
