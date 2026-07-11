{ lib, config, ...}: {
  config = lib.mkIf config.humanix.baseConfiguration {
    home-manager.users.${config.humanix.homeManagerUser} = { pkgs, ...}: {
      programs.starship = {
        enable = false;
        enableZshIntegration = false;
      };
    };
  };
}
