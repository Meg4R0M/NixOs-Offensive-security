# ─────────────────────────────────────────────────────────────────────────────
# Humanix · Bootloader GRUB-EFI (menu thémable phosphore vert)
# ─────────────────────────────────────────────────────────────────────────────
# Alternative à systemd-boot (non thémable). Activé par `humanix.bootloader =
# "grub"`. ⚠️ Cette machine est EFI (ESP /efi, kernels sur /boot non chiffré) :
# on installe GRUB en mode EFI (efiSupport + device="nodev"), PAS en BIOS
# (device="/dev/nvme0n1" + enableCryptodisk = l'ancien piège « refus … listes de
# blocs » sur disque GPT-EFI). Le LUKS reste déchiffré par l'initrd (GRUB lit les
# kernels en clair sur /boot), donc pas de cryptodisk.
{ lib, pkgs, config, ... }:
let
  # Thème graphique GRUB : fond dégradé sombre, titre HUMANIX + menu vert
  # phosphore, barre de timeout. Police Victor Mono convertie en .pf2 (grub-mkfont,
  # nom de famille forcé "HumanixMono" -> refs "HumanixMono Regular/Bold <taille>"
  # dans theme.txt).
  grubTheme = pkgs.runCommand "humanix-grub-theme"
    { nativeBuildInputs = [ pkgs.grub2 pkgs.imagemagick ]; } ''
    d=$out/share/grub/themes/humanix
    mkdir -p $d
    R=$(find ${pkgs.nerd-fonts.victor-mono} -name 'VictorMonoNerdFont-Regular.ttf' | head -1)
    B=$(find ${pkgs.nerd-fonts.victor-mono} -name 'VictorMonoNerdFont-Bold.ttf' | head -1)
    grub-mkfont    -n "HumanixMono" -s 18 -o $d/menu.pf2  "$R"
    grub-mkfont    -n "HumanixMono" -s 14 -o $d/small.pf2 "$R"
    grub-mkfont -b -n "HumanixMono" -s 32 -o $d/title.pf2 "$B"
    # Fond : dégradé vert très sombre -> noir (subtil, CRT).
    magick -size 1920x1080 gradient:'#00160a'-'#000000' $d/background.png
    cp ${./theme.txt} $d/theme.txt
  '';
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
        theme = "${grubTheme}/share/grub/themes/humanix";
      };
    };
  };
}
