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

  # LocalSend — partage de fichiers multi-plateforme (alternative AirDrop, P2P LAN).
  # openFirewall => ouvre 53317 TCP+UDP (réception + découverte multicast).
  programs.localsend = {
    enable = true;
    openFirewall = true;
  };

  # Deep-links des apps Electron (Slack…) : après login navigateur, l'app renvoie
  # un lien slack:// pour rendre la main. Chromium BLOQUE la redirection auto vers
  # les protocoles externes -> le retour de login se perdait (jamais les salons).
  # Le hand-off single-instance vers l'app marche déjà (SingletonLock OK) ; il
  # manquait l'autorisation NAVIGATEUR. Cette policy auto-lance slack:// depuis
  # slack.com sans dialogue. chromium = navigateur par défaut ; on couvre chrome.
  environment.etc =
    let deeplinks = builtins.toJSON {
      AutoLaunchProtocolsFromOrigins = [
        { protocol = "slack"; allowed_origins = [ "https://app.slack.com" "https://slack.com" ]; }
      ];
    };
    in {
      "chromium/policies/managed/humanix-deeplinks.json".text = deeplinks;
      "opt/chrome/policies/managed/humanix-deeplinks.json".text = deeplinks;
    };

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
    # 2-en-1 OmniBook Flip : accéléromètre, rotation auto niri, clavier écran, stylet.
    convertible.enable = true;
  };

  # Splash Plymouth — DIAGNOSTIC (2026-07-18) : thème STOCK "spinner" (plugin
  # two-step C + assets de prompt password) pour ISOLER thème custom vs pipeline
  # DRM sur ce combo AMD+LUKS+simpledrm. `splash` SANS `quiet` (cf plymouth.nix)
  # -> si le spinner ne rend pas, le prompt LUKS reste VISIBLE en texte (safe).
  # Résultats attendus : spinner tourne -> le pipeline est bon, c'était le thème
  # custom ; toujours du texte -> pipeline DRM (angle suivant : amdgpu en initrd).
  # Repli immédiat : remettre enable = false. Custom vert = theme = "humanix".
  humanix.aesthetic.plymouth.enable = true;
  humanix.aesthetic.plymouth.theme = "spinner";

  # Login CRACKTRO demoscene (cf modules/dms/greetd/default.nix) : remplace
  # tuigreet par une session sway — shader GLSL Amiga (glpaper : copper bars,
  # plasma, starfield, logo + scroller sinus) + gtkgreet vert + chiptune 8-bit
  # « A Night Of Dizzy Spells » (Eric Skiff, CC-BY). Repli = enable=false ;
  # échappatoire si le login graphique casse : Ctrl+Alt+F2 -> TTY texte.
  humanix.login.cracktro.enable = true;

  # Profil d'ambiance (cf modules/design/aesthetic.nix) : showtime | work | client.
  # showtime = wallpaper animé + bannière MOTD. Passe en "client" en clientèle.
  humanix.aesthetic.profile = "showtime";

  # HexStrike AI : serveur MCP d'outils pentest, piloté par Claude Code (sans API,
  # sans Docker). Serveur d'outils sur 127.0.0.1:8888. Après switch, lancer une
  # fois `hexstrike-setup-claude`. (cf modules/cyber/hexstrike.nix)
  humanix.ai.hexstrike.enable = true;

  # DefectDojo : DÉSACTIVÉ temporairement — l'init bloquant a gelé un switch 1h25
  # (NSS/users cassés). Module corrigé (init non-bloquant + timeout) ; réactiver
  # volontairement quand prêt. (cf modules/cyber/defectdojo.nix)
  humanix.ai.defectdojo.enable = false;

  # KittySploit : framework d'exploitation + serveur MCP (piloté par Claude, sans
  # API). ACTIVÉ : après switch, lance une fois `kittysploit` (clone + venv au 1er
  # run, réseau requis) puis `kittysploit-setup-claude` pour brancher le MCP.
  # (cf modules/cyber/kittysploit.nix)
  humanix.ai.kittysploit.enable = true;

  # Exegol : environnement pentest Docker (image free). Après switch :
  # `exegol install free` (tire l'image) puis `exegol start free`.
  # (cf modules/cyber/exegol.nix)
  humanix.exegol.enable = true;

  # Shader d'animation ouverture/fermeture des fenêtres niri (liixini/shaders).
  # Ambiance Mr Robot -> "glitch" (artefacts numériques). Autres : voir README/§shaders.
  humanix.niriShader = "glitch";

  # Kernel CachyOS variante LTS/BORE (base 6.18.38 = base actuelle qui boote +
  # patchs perf). Le hardened bleeding-edge (7.0.12) paniquait sur cet APU.
  humanix.kernel.cachyos.enable = true;
  humanix.kernel.cachyos.variant = "bore"; # test 7.1.3 BORE ; repli "lts" (6.18) si panic
}
