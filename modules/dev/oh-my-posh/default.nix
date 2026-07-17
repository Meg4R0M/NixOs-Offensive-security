{ lib, config, ... }: {
  config = lib.mkIf config.humanix.baseConfiguration {
    home-manager.users.${config.humanix.homeManagerUser} = { pkgs, ... }: {
      # Prompt oh-my-posh — thème tokyo (JanDeDobbeleer) RECOLORÉ en vert Mr Robot
      # (structure/segments d'origine : time/session/RAM/batterie/exec-time,
      # az/aws/gcp/k8s, path, git, status). Remplace Starship.
      programs.oh-my-posh = {
        enable = true;
        enableZshIntegration = true;
        settings = builtins.fromJSON (builtins.readFile ./tokyo-green.omp.json);
      };
    };
  };
}
