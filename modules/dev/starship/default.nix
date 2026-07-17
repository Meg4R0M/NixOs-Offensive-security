{ lib, config, ...}: {
  config = lib.mkIf config.humanix.baseConfiguration {
    home-manager.users.${config.humanix.homeManagerUser} = { pkgs, ...}: {
      # Prompt remplacé par oh-my-posh (thème tokyo recoloré vert) : Starship OFF.
      # cf modules/dev/oh-my-posh.
      programs.starship.enable = false;
      programs.starship.enableZshIntegration = false;
    };
  };
}
