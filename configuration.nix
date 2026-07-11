# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ lib, config, pkgs, ... }:
let
  # These variable names are used by Aegis backend
  version = "unstable"; #unstable or 25.05
  username = "fdurano";
  hostname = "Humanix";
  theme = "hackthebox";
  desktop = "gnome";
  dmanager = "greetd"; # login console Humanix (tuigreet). Repli : "sddm"
  sddmtheme = "post-apocalyptic_hacker";
  mainShell = "zsh";
  terminal = "wezterm";
  browser = "firefox";
  # ⚠️ En éval flake PURE, builtins.pathExists "/sys/firmware/efi" renvoie false
  # (accès hors-flake interdit) => la détection basculait à tort sur GRUB-BIOS,
  # qui échoue sur ce disque GPT-EFI (« refus de continuer avec les listes de
  # blocs »). Cette machine est EFI et boote systemd-boot (ESP /efi) => on fige.
  bootloader = "systemd";
  # home-manager n'est plus fetchTarball ici : il vient du flake
  # (inputs.home-manager.nixosModules.home-manager, cf flake.nix).
in
{
  imports = [ # Include the results of the hardware scan.
    {
      humanix = {
        inherit bootloader terminal theme mainShell browser;
        enable = true;
        homeManagerUser = username;
        baseConfiguration = true;
        baseSoftware = true;
        baseLocale = true;
        desktopManager = desktop;
        displayManager = dmanager;
        sddmTheme = sddmtheme;
        enableHyprland = true;
        enableNiri = true;
        useStylix = true;
      };
    }
    ./hardware-configuration.nix
    ./.
    ./modules/claude-desktop.nix
  ];

  users = lib.mkIf config.humanix.enable {
    mutableUsers = false;
    # Lus à l'activation (hors flake, cf secrets/ gitignoré).
    extraUsers.root.hashedPasswordFile = "/home/fdurano/nixos/secrets/root.hash";
    users.${config.humanix.homeManagerUser} = {
      shell = pkgs.${config.humanix.mainShell};
      isNormalUser = true;
      hashedPasswordFile = "/home/fdurano/nixos/secrets/user.hash";
      extraGroups = [ "docker" "wheel" ];
    };
  };

  # Certaines apps (zellij) réécrivent leur config au démarrage et écrasent le
  # symlink home-manager. On demande à HM de sauvegarder au lieu d'échouer.
  home-manager.backupFileExtension = "hmbak";

  networking = {
    hostName = "${hostname}";
    enableIPv6 = false;
  };

  services.flatpak.enable = true;

  # Flakes activés (nécessaire pour `nixos-rebuild switch --flake`).
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  cyber = {
    enable = true;
    role = "cracker";
    # Humanix : arsenal cyber COMPLET (union des 12 rôles, ~430 paquets).
    roles = [ "blue" "bugbounty" "dos" "forensic" "malware" "mobile" "network" "osint" "red" "student" "web" ];
  };

  # Arsenal RF/embarqué (cf modules/hardware/arsenal.nix). GUI SDR lourdes
  # (gqrx/gnuradio/urh) laissées opt-in le temps de valider le 1er build.
  humanix.hardware = {
    arsenal.enable = true;
    sdr.enable = true;
    sdr.gui.enable = false;
    embedded.enable = true;
  };

  # Splash Plymouth DÉSACTIVÉ : sur ce combo AMD+LUKS il n'affichait pas le prompt
  # de passphrase (ESC requis). Sans splash => prompt LUKS en texte vert (vconsole
  # Stylix), fiable et sans ESC. Le graphique pourra être retenté plus tard.
  humanix.aesthetic.plymouth.enable = false;

  # Profil d'ambiance (cf modules/design/aesthetic.nix) : showtime | work | client.
  # showtime = wallpaper animé + bannière MOTD. Passe en "client" en clientèle.
  humanix.aesthetic.profile = "showtime";

  # Kernel CachyOS variante LTS/BORE (base 6.18.38 = base actuelle qui boote +
  # patchs perf). Le hardened bleeding-edge (7.0.12) paniquait sur cet APU.
  humanix.kernel.cachyos.enable = true;
  humanix.kernel.cachyos.variant = "bore"; # test 7.1.3 BORE ; repli "lts" (6.18) si panic
}
