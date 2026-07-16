{ lib, config, ...}: {
  config = lib.mkIf config.humanix.baseConfiguration {
    home-manager.users.${config.humanix.homeManagerUser} = { pkgs, ...}: {
      # Stylix thème aussi starship (palette base16) -> conflit. On gère le vert
      # nous-mêmes, donc on coupe la cible Stylix starship.
      stylix.targets.starship.enable = false;

      # Prompt Starship — informatif (user@host, IP locale, dir, git, durée, venv,
      # k8s/aws) et thémé VERT Mr Robot. Remplace le prompt Athena peu parlant.
      programs.starship = {
        enable = true;
        enableZshIntegration = true;
        settings = {
          add_newline = true;
          palette = "humanix";
          palettes.humanix = {
            green = "#00ff41"; dim = "#00cc33"; teal = "#00d38a";
            red = "#ff2b2b"; amber = "#ffb000";
          };
          format = lib.concatStrings [
            "[╭─](green)$os$username[@](dim)$hostname $localip$directory$git_branch$git_status$python$nodejs$kubernetes$aws$cmd_duration"
            "$line_break"
            "[╰─](green)$character"
          ];
          os = { disabled = false; format = "[$symbol](green)"; symbols.NixOS = " "; };
          username = { show_always = true; format = "[$user]($style)"; style_user = "bold green"; style_root = "bold red"; };
          hostname = { ssh_only = false; format = "[$hostname]($style)"; style = "bold dim"; };
          localip = { ssh_only = false; disabled = false; format = "[󰩠 $localipv4](teal) "; };
          directory = { style = "bold green"; truncation_length = 4; truncate_to_repo = false; read_only = " "; };
          git_branch = { symbol = " "; style = "amber"; format = "[$symbol$branch]($style) "; };
          git_status = { style = "red"; };
          cmd_duration = { min_time = 500; format = "[󱎫 $duration]($style) "; style = "dim"; };
          python = { symbol = " "; style = "teal"; format = "[$symbol$version]($style) "; };
          kubernetes = { disabled = false; symbol = "󱃾 "; style = "teal"; format = "[$symbol$context]($style) "; };
          aws = { symbol = " "; style = "amber"; };
          character = {
            success_symbol = "[❯](bold green)";
            error_symbol = "[❯](bold red)";
            vimcmd_symbol = "[❮](bold green)";
          };
        };
      };
    };
  };
}
