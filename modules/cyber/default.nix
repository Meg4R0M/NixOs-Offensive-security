{ lib, config, pkgs, ... }:

with lib;

let
  roles = {
    blue      = import ./roles/blue.nix { inherit pkgs; };
    bugbounty = import ./roles/bugbounty.nix { inherit pkgs; };
    cracker   = import ./roles/cracker.nix { inherit pkgs; };
    dos       = import ./roles/dos.nix { inherit pkgs; };
    forensic  = import ./roles/forensic.nix { inherit pkgs; };
    malware   = import ./roles/malware.nix { inherit pkgs; };
    mobile    = import ./roles/mobile.nix { inherit pkgs; };
    network   = import ./roles/network.nix { inherit pkgs; };
    osint     = import ./roles/osint.nix { inherit pkgs; };
    red       = import ./roles/red.nix { inherit pkgs; };
    student   = import ./roles/student.nix { inherit pkgs; };
    web       = import ./roles/web.nix { inherit pkgs; };
  };
in {
  options.cyber = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable the cyber module to install cyber security tools based on role.";
    };

    role = mkOption {
      type = types.enum [
        "blue"
        "bugbounty"
        "cracker"
        "dos"
        "forensic"
        "malware"
        "mobile"
        "network"
        "osint"
        "red"
        "student"
        "web"
      ];
      default = "student";
      description = "Cyber role to determine which set of tools to install. Options are 'blue', 'bugbounty', 'cracker', 'dos', 'forensic', 'malware', 'mobile', 'network', 'osint', 'red', 'student' or 'web'.";
      example = "student";
    };

    # Humanix : rôles supplémentaires à installer EN PLUS de `role` (union
    # dédupliquée). Permet un arsenal complet (tous les rôles pertinents).
    roles = mkOption {
      type = types.listOf (types.enum [
        "blue" "bugbounty" "cracker" "dos" "forensic" "malware"
        "mobile" "network" "osint" "red" "student" "web"
      ]);
      default = [ ];
      example = [ "red" "network" "web" "osint" ];
      description = "Rôles cyber à unir en plus de `role` (dédupliqué).";
    };
  };

  config = mkIf config.cyber.enable {
    # Union (dédupliquée) de role + roles -> arsenal complet possible.
    environment.systemPackages =
      let selected = lib.unique ([ config.cyber.role ] ++ config.cyber.roles);
      in lib.unique (lib.concatMap (r: builtins.getAttr r roles) selected);
  };
}
