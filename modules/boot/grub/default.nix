# ─────────────────────────────────────────────────────────────────────────────
# Humanix · Bootloader GRUB-EFI (thème Mr Robot)
# ─────────────────────────────────────────────────────────────────────────────
# Alternative à systemd-boot (non thémable). Activé par `humanix.bootloader =
# "grub"`. ⚠️ Machine EFI (ESP /efi, kernels sur /boot non chiffré) : GRUB en
# mode EFI (efiSupport + device="nodev"), PAS en BIOS (device="/dev/nvme0n1" +
# enableCryptodisk = l'ancien piège « refus … listes de blocs » sur GPT-EFI). Le
# LUKS reste déchiffré par l'initrd, donc pas de cryptodisk.
#
# Thème : johdasgran/mr-robot-theme (fond Mr Robot, menu rouge fsociety, polices
# Tomb Raider .pf2 bundlées, pixmaps + icônes distro). Auto-suffisant.
{ lib, pkgs, config, ... }:
let
  grubTheme = pkgs.fetchFromGitHub {
    owner = "johdasgran";
    repo = "mr-robot-theme";
    rev = "6f40221ff51fcf7dd9f63391ad7ce4ac9ef53650";
    sha256 = "0f0iqm4hf2m4b9cl4jw9xnwq8w48xm33x9wjjlrbfj9dzpg9kyj8";
  };
in {
  config = lib.mkIf (config.humanix.bootloader == "grub") {
    # Humanix pilote le thème GRUB : jamais celui de Stylix (sinon conflit).
    stylix.targets.grub.enable = false;

    boot.loader = {
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = "/efi";
      grub = {
        enable = true;
        efiSupport = true;
        device = "nodev";          # EFI (pas de MBR/BIOS)
        configurationLimit = 5;
        gfxmodeEfi = "auto";
        theme = grubTheme;         # la racine du repo contient theme.txt
      };
    };
  };
}
