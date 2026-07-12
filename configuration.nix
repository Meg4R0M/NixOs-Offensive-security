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
    # ⚠️ Nix ne gère PLUS AUCUN mot de passe (retour d'expérience : hashedPassword/
    # hashedPasswordFile a cassé le login → récupération via live USB).
    # mutableUsers = true => /etc/shadow PERSISTE, mots de passe gérés à la main
    # (`passwd`). Aucun switch ne peut plus verrouiller le compte, et aucun hash
    # ne traîne dans le repo git.
    mutableUsers = true;
    users.${config.humanix.homeManagerUser} = {
      shell = pkgs.${config.humanix.mainShell};
      isNormalUser = true;
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

  # HexStrike AI : serveur MCP d'outils pentest, piloté par Claude Code (sans API,
  # sans Docker). Serveur d'outils sur 127.0.0.1:8888. Après switch, lancer une
  # fois `hexstrike-setup-claude`. (cf modules/cyber/hexstrike.nix)
  humanix.ai.hexstrike.enable = true;

  # DefectDojo : dashboard bug bounty (7 conteneurs oci-containers docker) +
  # serveur MCP pour que Claude gère les findings. UI 127.0.0.1:8080.
  # Après switch : `defectdojo-setup-claude`. (cf modules/cyber/defectdojo.nix)
  humanix.ai.defectdojo.enable = true;

  # Shader d'animation ouverture/fermeture des fenêtres niri (liixini/shaders).
  # Ambiance Mr Robot -> "glitch" (artefacts numériques). Autres : voir README/§shaders.
  humanix.niriShader = "glitch";

  # Kernel CachyOS variante LTS/BORE (base 6.18.38 = base actuelle qui boote +
  # patchs perf). Le hardened bleeding-edge (7.0.12) paniquait sur cet APU.
  humanix.kernel.cachyos.enable = true;
  humanix.kernel.cachyos.variant = "bore"; # test 7.1.3 BORE ; repli "lts" (6.18) si panic
}
