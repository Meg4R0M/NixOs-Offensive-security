# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ lib, config, pkgs, ... }:
let
  # These variable names are used by Aegis backend
  version = "unstable"; #unstable or 25.05
  username = "fdurano";
  # Hashes mot de passe sortis du repo -> ./secrets.nix (gitignoré, cf secrets.nix.example)
  secrets = import ./secrets.nix;
  hostname = "Humanix";
  theme = "hackthebox";
  desktop = "gnome";
  dmanager = "greetd"; # login console Humanix (tuigreet). Repli : "sddm"
  sddmtheme = "post-apocalyptic_hacker";
  mainShell = "zsh";
  terminal = "wezterm";
  browser = "firefox";
  bootloader = if builtins.pathExists "/sys/firmware/efi" then "systemd" else "grub";
  hm-version = if version == "unstable" then "master" else "release-" + version; # Correspond to home-manager GitHub branches
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/${hm-version}.tar.gz";
in
{
  imports = [ # Include the results of the hardware scan.
    {
      athena = {
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
    (import "${home-manager}/nixos")
    ./hardware-configuration.nix
    ./.
    ./modules/claude-desktop.nix
  ];

  users = lib.mkIf config.athena.enable {
    mutableUsers = false;
    extraUsers.root.hashedPassword = secrets.hashedRoot;
    users.${config.athena.homeManagerUser} = {
      shell = pkgs.${config.athena.mainShell};
      isNormalUser = true;
      hashedPassword = secrets.hashed;
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

  cyber = {
    enable = true;
    role = "cracker";
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

  # Kernel CachyOS variante LTS/BORE (base 6.18.38 = base actuelle qui boote +
  # patchs perf). Le hardened bleeding-edge (7.0.12) paniquait sur cet APU.
  humanix.kernel.cachyos.enable = true;
  # humanix.kernel.cachyos.variant = "lts"; # défaut ; "hardened" = bleeding-edge
}
