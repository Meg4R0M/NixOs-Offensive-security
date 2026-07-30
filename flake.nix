{
  description = "Humanix — distro offensive (fork Athena OS · NixOS · compositor niri)";

  inputs = {
    # nixpkgs sur la branche nixos-unstable (DÉPINGLÉ le 2026-07-30 pour la màj
    # sécu). `nix flake update nixpkgs` met à jour ; re-pin sur une rev si besoin de
    # figer. (L'ancien pin 0bb7ec5 servait à éviter le rebuild massif — plus le but.)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Stylix (theming) — DÉPINGLÉ (suit nixpkgs) : sa rev doit rester compatible
    # avec nixpkgs, donc on la bump en même temps (branche master de stylix).
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Kernel CachyOS (branche release = synchro avec le cache binaire Attic).
    # PAS de follows nixpkgs : l'overlay `pinned` utilise SES propres deps pour
    # rester compatible avec le cache (sinon on recompile le kernel).
    cachyos.url = "github:xddxdd/nix-cachyos-kernel/4673c8f6d48baf2ec3f14b6a9f8c4ecfb0810d6f";

    # Claude Desktop. Bump 2026-07-23 : df943e84 ajoute requestSingleInstanceLock +
    # second-instance → corrige la boucle de login OAuth (claude:// non forwardé).
    claude.url = "github:Reginleif88/claude-cowork-nix/df943e84313977fdca5751023a13b6de5157c035";

    # agenix — secrets chiffrés versionnables (clés API OSINT, profils WireGuard).
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # RedNix (redcode-labs) — outils offensifs maison hors nixpkgs.
    # PAS de follows nixpkgs : on réutilise ses builds (cache binaire).
    rednix.url = "github:redcode-labs/RedNix";

    # cshell — shell Quickshell (barre + dashboard + OSD) pour niri.
    # Pas de follows : il pinne son nixpkgs pour la compat quickshell/qt6.
    cshell.url = "github:chaeu-srk/cshell/3fdd86a9fb1c29e714570715d683ad9380de4f6d";

    # niri-glass — fork de niri (26.04) avec effet « liquid glass » (réfraction).
    # Pas de follows : l'overlay remplace des fichiers source niri, il DOIT être
    # bâti contre sa base pinnée (niri 26.04, rev 49fc611). Swap du binaire niri.
    niri-glass.url = "github:zaroutt/Niri-glass/5ff51970491486c674ce293e13af9c644c2db514";

    # Noctalia — shell Wayland natif complet (barre/dock/launcher/control center/
    # notifs/presse-papier/OSD/lock/wallpaper). v5, module HM + thème par palette.
    # Remplace cshell. Pas de follows (build C++ autonome).
    noctalia.url = "github:noctalia-dev/noctalia/d6405bb0e3324451a3286482137a1c399e1b259b";

    # widgets.wez — widgets de status bar wezterm (CPU/RAM/batterie/réseau/disque).
    # flake = false : simple arbre source Lua, vendoré dans le store et chargé via
    # package.path (pas de wezterm.plugin.require -> pas de clone git au runtime).
    widgets-wez = {
      url = "github:usrivastava92/widgets.wez";
      flake = false;
    };

    # electric-control-room.wez — thème + fond d'écran animé (sweep APNG + état
    # dormant idle). flake = false : source Lua + assets APNG recolorés cyan->vert
    # phosphore dans une dérivation, chargés via dofile + assets_dir (pas de
    # wezterm.plugin.require -> pas de clone git au runtime).
    electric-control-room = {
      url = "github:Tomauskasz/electric-control-room.wez";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      # devShell par catégorie : `nix develop .#cloud` charge un sous-arsenal
      # ponctuel sans l'installer sur le système (pattern redcode-labs/RedNix).
      shell = name: pkgList: pkgs.mkShellNoCC {
        packages = pkgList;
        shellHook = "echo '── Humanix devShell : ${name} ──'";
      };
    in
    {
      nixosConfigurations.Humanix = nixpkgs.lib.nixosSystem {
        inherit system;
        # `inputs` dispo dans TOUS les modules (stylix/cachyos/claude/rednix).
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          inputs.home-manager.nixosModules.home-manager
          inputs.agenix.nixosModules.default
        ];
      };

      # Sous-arsenaux à la demande : nix develop /home/fdurano/nixos#<catégorie>
      devShells.${system} = {
        cloud = shell "cloud" (with pkgs; [ pacu cloudfox trivy grype kubescape kdigger prowler noseyparker ]);
        ad    = shell "ad"    (with pkgs; [ certipy kerbrute ldeep responder ]);   # netexec+bloodhound-py retirés (TEMP: cassés nixpkgs 07-29)
        web   = shell "web"   (with pkgs; [ nuclei httpx katana ffuf feroxbuster dalfox subfinder gowitness ]);
        rf    = shell "rf"    (with pkgs; [ rtl-sdr hackrf gnuradio killerbee ubertooth gallia can-utils ]);
        osint = shell "osint" (with pkgs; [ sn0int maigret holehe h8mail theharvester amass ]);
      };
    };
}
