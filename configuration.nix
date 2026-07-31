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
  # GRUB-EFI (menu thémé Mr Robot, cf modules/boot/grub). ⚠️ mode EFI (efiSupport
  # + device="nodev"), PAS le BIOS (device="/dev/nvme0n1" + cryptodisk = l'ancien
  # piège « refus … listes de blocs » sur GPT-EFI). Machine EFI (ESP /efi, kernels
  # sur /boot non chiffré, LUKS déchiffré par l'initrd). Validé en VM avant bascule.
  # Repli 1 ligne : "systemd" (revert : F9 firmware ou live-USB, cf historique).
  bootloader = "grub";
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

  # Splash Plymouth : thème vert HUMANIX (logo phosphore + spinner + prompt LUKS
  # vert), sur le moteur two-step PROUVÉ au diagnostic (le pipeline DRM rend bien ;
  # l'ancien échec = le plugin `script`). `splash` SANS `quiet` (cf plymouth.nix)
  # -> les logs noyau/init défilent (vibe dmesg voulue), le splash s'affiche sur
  # le prompt de déchiffrement + le spinner. Repli = enable=false ; diag stock =
  # theme = "spinner".
  humanix.aesthetic.plymouth.enable = true;
  humanix.aesthetic.plymouth.theme = "humanix";

  # ── Boot « logs hacker » : console en palette PHOSPHORE VERT ────────────────
  # Au lieu du cyberpunk Stylix, les logs noyau/init/systemd qui défilent au boot
  # (et les TTY) ressortent en vert vif, avec les statuts systemd colorés (OK vert
  # / FAILED rouge / warn ambre). Index 7/15 (fg par défaut) = vert -> tout le
  # texte console devient vert. (console.colors pose aussi vt.default_* en
  # kernelParams -> vaut dès le boot précoce, fini le texte « fade ».)
  stylix.targets.console.enable = lib.mkForce false;
  # Palette VIVE et VARIÉE : corps de texte vert phosphore (index 7), mais accents
  # bien distincts -> les statuts systemd [OK]/[FAILED]/warn pètent, et toute sortie
  # ANSI (TTY, logs colorés) sort en vraies couleurs. Le gras (15) = blanc-vert.
  console.colors = [
    "0a0f0a" "ff2b2b" "00ff41" "ffb000"  # 0-3  noir / rouge(FAIL) / vert(OK) / ambre(warn)
    "2f81f7" "ff5cd6" "00e5d0" "00c83c"  # 4-7  bleu / magenta / cyan / VERT (fg défaut)
    "1f4d1f" "ff6b6b" "39ff14" "ffd257"  # 8-11 brights
    "6ba9ff" "ff8ce6" "5cffe8" "eafff0"  # 12-15 brights + blanc-vert
  ];

  # Menu systemd-boot : résolution max (texte net) + timeout court.
  boot.loader.systemd-boot.consoleMode = lib.mkForce "max";
  boot.loader.timeout = lib.mkForce 3;

  # Boot plus court : NetworkManager-wait-online bloque multi-user.target ~10 s en
  # attendant le réseau (inutile AVANT le login) -> greetd démarre plus tôt, moins
  # d'écritures avant le login. Revert = enable = true. (systemd-analyze blame pour
  # traquer d'autres lenteurs si besoin.)
  systemd.services.NetworkManager-wait-online.enable = false;

  # IBus (méthode de saisie, hérité d'Athena) : inutile en AZERTY sans saisie CJK,
  # et sous niri/Wayland il n'est pas géré par la session -> notif « IBus devrait
  # être appelé par la session de bureau » à chaque login. Désactivé. (Besoin de
  # CJK/emoji IBus un jour ? -> on le recâble proprement dans le spawn niri.)
  i18n.inputMethod.enable = lib.mkForce false;

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
  # API). ACTIVÉ + `autostart` (défaut) : au login, un service systemd user fait
  # le bootstrap (clone + venv, réseau) PUIS enregistre le MCP auprès de Claude
  # (Code + Desktop) -> prêt sans étape manuelle. (cf modules/cyber/kittysploit.nix)
  humanix.ai.kittysploit.enable = true;

  # Exegol : environnement pentest Docker (image free). Après switch :
  # `exegol install free` (tire l'image) puis `exegol start free`.
  # (cf modules/cyber/exegol.nix)
  humanix.exegol.enable = true;

  # Durcissement système (cf modules/security/hardening.nix) : sudo wheel-only,
  # auditd (execve), nix @wheel, firewall assumé + sysctl noyau/réseau CHOISIS pour
  # ne pas brider l'offensif (rp_filter/ptrace/BPF/userns laissés intacts).
  humanix.hardening.enable = true;

  # iCloud Drive via rclone (cf modules/cloud/icloud.nix). Le bug d'auth 2FA de
  # rclone 1.74.4 (HTTP 409, rclone/rclone#9324) est CORRIGÉ par un patch local.
  # Config une fois : `rclone config` (remote "icloud", iclouddrive, Apple ID + 2FA)
  # puis `systemctl --user start rclone-icloud`.
  humanix.cloud.icloud.enable = true;

  # Shader d'animation ouverture/fermeture des fenêtres niri (liixini/shaders).
  # Ambiance Mr Robot -> "glitch" (artefacts numériques). Autres : voir README/§shaders.
  humanix.niriShader = "glitch";

  # Kernel CachyOS variante LTS/BORE (base 6.18.38 = base actuelle qui boote +
  # patchs perf). Le hardened bleeding-edge (7.0.12) paniquait sur cet APU.
  humanix.kernel.cachyos.enable = true;
  humanix.kernel.cachyos.variant = "bore"; # test 7.1.3 BORE ; repli "lts" (6.18) si panic
}
