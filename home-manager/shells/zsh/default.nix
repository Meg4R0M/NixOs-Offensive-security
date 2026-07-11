{ lib, pkgs, config, ... }:
with lib;
let
  shopt = pkgs.writeShellScriptBin "shopt" (builtins.readFile ./shopt);
in {
  config = mkIf (config.athena.mainShell == "zsh") {
    # System-level packages so their .zsh files are available
    environment.systemPackages = with pkgs; [
      nix-zsh-completions
      zsh-autosuggestions
      zsh-syntax-highlighting
    ];

    home-manager.users.${config.athena.homeManagerUser} = { pkgs, config, ...}: {
      home.packages = with pkgs; [
        fastfetch
        shopt
      ];

      # Multiplexeur terminal par défaut : zellij démarre automatiquement à
      # l'ouverture d'un terminal (wezterm) via zsh.
      programs.zellij = {
        enable = true;
        enableZshIntegration = true;
        settings = {
          theme = "mrrobot";
          # Thème vert CRT (Mr Robot) + accents rouge DARK-4RMY.
          themes.mrrobot = {
            fg      = "#00ff41";
            bg      = "#0a0f0a";
            black   = "#0a0f0a";
            red     = "#ff2b2b";
            green   = "#00ff41";
            yellow  = "#ffb000";
            blue    = "#00b32d";
            magenta = "#39ff14";
            cyan    = "#00ff87";
            white   = "#d4ffd4";
            orange  = "#ff2b2b";
          };
          # Barre de statut compacte, sans bordures criardes.
          pane_frames = false;
          simplified_ui = true;
        };
      };

      programs.zsh = {
        enable = true;

        # ---------- History ----------
        history = {
          path = "${config.home.homeDirectory}/.zsh_history";
          size = 10000;   # HISTSIZE
          save = 1000;    # SAVEHIST
          expireDuplicatesFirst = true;
        };

        # ---------- Options ----------
        setOptions = [
          "INC_APPEND_HISTORY"
        ];

        # ---------- Completions & zplug ----------
        enableCompletion = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;

        zplug = {
          enable = true;
          plugins = [
            { name = "zsh-users/zsh-autosuggestions"; }
            { name = "zsh-users/zsh-history-substring-search"; }
            { name = "zsh-users/zsh-syntax-highlighting"; }
            # { name = "romkatv/powerlevel10k"; tags = [ as:theme depth:1 ]; } # Uncomment to use powerlevel10k plugin
          ];
        };

        # ---------- Aliases ----------
        shellAliases = {
          shopt = "/run/current-system/sw/bin/shopt";
          # ll = "ls -l";
          # update = "sudo nixos-rebuild switch";
          nrs = "sudo nixos-rebuild switch -I nixos-config=$HOME/nixos/configuration.nix";
          # Test sans appliquer (à lancer avant nrs/nru en cas de doute)
          nrt = "sudo nixos-rebuild dry-build -I nixos-config=$HOME/nixos/configuration.nix";
          # Update complet : channel nixpkgs + rebuild switch
          nru = "sudo nix-channel --update && sudo nixos-rebuild switch -I nixos-config=$HOME/nixos/configuration.nix";
          # Nettoyage des anciennes générations (>14 jours) + GC
          nrgc = "sudo nix-collect-garbage --delete-older-than 14d && nix-collect-garbage -d";
          # Relance les 3 conky en daemon (-d = détaché, rend la main au shell)
          conky-reload = "pkill -9 conky 2>/dev/null; sleep 1; for c in monitor host clock cal cyber veille2; do conky -d -c $HOME/.config/conky/haxos-$c.conf; done";
        };

        # ---------- What compinit adds (kept from your file) ----------
        completionInit = ''
          # The following lines were added by compinstall
          zstyle :compinstall filename "$HOME/.zshrc"
          autoload -U +X bashcompinit && bashcompinit
          autoload -U +X compinit && compinit
          # End of lines added by compinstall
        '';

        # ---------- Content init after completion ----------
        initContent = ''
          # Emacs-style keymap
          bindkey -e

          # Keybindings
          bindkey "^[[1;5C" forward-word
          bindkey "^[[1;5D" backward-word
          bindkey "\e[1~" beginning-of-line
          bindkey "\e[4~" end-of-line
          bindkey "\e[5~" beginning-of-history
          bindkey "\e[6~" end-of-history
          bindkey "\e[7~" beginning-of-line
          bindkey "\e[3~" delete-char
          bindkey "\e[2~" quoted-insert
          bindkey "\e[5C" forward-word
          bindkey "\e[5D" backward-word
          bindkey "\e\e[C" forward-word
          bindkey "\e\e[D" backward-word
          bindkey "\e[1;5C" forward-word
          bindkey "\e[1;5D" backward-word
          bindkey "\e[8~" end-of-line
          bindkey "\eOH" beginning-of-line
          bindkey "\eOF" end-of-line
          bindkey "\e[H" beginning-of-line
          bindkey "\e[F" end-of-line

          # Things you wanted once per interactive shell start
          source ~/.bash_aliases 2>/dev/null || true
          # fastfetch s'affiche DANS zellij (évite le double flash : le shell
          # externe exec zellij, l'accueil s'affiche dans le panneau).
          if [[ -n "$ZELLIJ" ]]; then fastfetch || true; fi

        # ---------- Prompt & precmd hook ----------
          function build_prompt() {
            local last_status=$?
            local tty_device=$(tty)
            local ip=$(ip -4 addr | grep -v '127.0.0.1' | grep -v 'secondary' \
              | grep -oP '(?<=inet\s)\d+(\.\d+){3}' \
              | sed -z 's/\n/|/g;s/|\$/\n/' \
              | rev | cut -c 2- | rev)

            local user="%n"
            local host="%m"
            local cwd="%~"
            local branch=""
            local hq_prefix=""
            local flame=""
            local robot=""

            # Git branch detection
            if command -v git &>/dev/null; then
              branch=$(git symbolic-ref --short HEAD 2>/dev/null)
            fi

            # Emoji mode detection
            if [[ "$tty_device" == /dev/tty* ]]; then
              hq_prefix="HQ─"
              flame=""
              robot="[>]"
            else
              hq_prefix="HQ🚀🌐"
              flame="🔥"
              robot="[👾]"
            fi

            # Color for user@host based on last status
            local user_host
            if [[ $last_status -eq 0 ]]; then
              user_host="%F{blue}($user@$host)%f"
            else
              user_host="%F{red}($user@$host)%f"
            fi

            # First line
            local line1="%F{46}╭─[$hq_prefix%F{196}$ip%F{46}$flame]─$user_host"
            if [[ -n "$branch" ]]; then
              line1+="%F{220}[ $branch]%f"
            fi

            # Second line
            local line2="%F{46}╰─>$robot%F{44}$cwd $%f"

            PROMPT="$line1"$'\n'"$line2 "
          }

          autoload -Uz add-zsh-hook
          add-zsh-hook precmd build_prompt
        '';
      };
    };
  };
}
