{
  description = "Humanix — distro offensive (fork Athena OS · NixOS · compositor niri)";

  inputs = {
    # nixpkgs PINNÉ sur le rev actuel du système => aucun rebuild massif au passage
    # en flake. `nix flake update nixpkgs` pour mettre à jour volontairement.
    nixpkgs.url = "github:NixOS/nixpkgs/0bb7ec54c8483066ec9d7720e780a5caa71f8612";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Stylix (theming) — rev compatible nixpkgs 26.11 (déjà utilisé auparavant).
    stylix = {
      url = "github:nix-community/stylix/a378e4c09031fb15a4d65da88aa628f71fc52f6b";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Kernel CachyOS (branche release = synchro avec le cache binaire Attic).
    # PAS de follows nixpkgs : l'overlay `pinned` utilise SES propres deps pour
    # rester compatible avec le cache (sinon on recompile le kernel).
    cachyos.url = "github:xddxdd/nix-cachyos-kernel/4673c8f6d48baf2ec3f14b6a9f8c4ecfb0810d6f";

    # Claude Desktop.
    claude.url = "github:Reginleif88/claude-cowork-nix/5018f7912405c1559314f56bc587ee6318d60132";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations.Humanix = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      # `inputs` dispo dans TOUS les modules (stylix/cachyos/claude s'y branchent).
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        inputs.home-manager.nixosModules.home-manager
      ];
    };
  };
}
