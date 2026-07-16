{ lib, pkgs, config, ... }:
with lib;
let
  shopt = pkgs.writeShellScriptBin "shopt" (builtins.readFile ./shopt);

  # ── Historique de commandes Exegol ──────────────────────────────────────────
  # Exegol ne fournit pas un vrai .zsh_history rempli (le skel est vide) : les
  # commandes utiles sont dans ~161 fichiers d'ALIASES (aliases.d). On extrait le
  # CORPS des alias (l'invocation réelle) -> un fichier d'historique -> semé une
  # fois dans ~/.zsh_history pour que zsh-autosuggestions les propose.
  # ⚠️ ces commandes visent des chemins conteneur (/opt/tools/…) : ce sont des
  #    patterns de référence, à lancer DANS Exegol.
  exegolSrc = pkgs.fetchFromGitHub {
    owner = "ThePorgs";
    repo = "Exegol-images";
    rev = "bb448e76d254bc49c4b900e2494c47e00b9f964f";
    sha256 = "1xfpcm8blzk4366m1ihjspqsmjwm085c3ny01128f5zgcqx9chxq";
  };
  exegolHistory = pkgs.runCommand "exegol-commands-history" { } ''
    cat ${exegolSrc}/sources/assets/shells/aliases.d/* 2>/dev/null \
      | grep -hE "^alias " \
      | sed -E "s/^alias [^=]+=//" \
      | sed -E "s/^'(.*)'$/\1/; s/^\"(.*)\"$/\1/" \
      | grep -vE '^[[:space:]]*$' \
      | awk '!seen[$0]++' \
      > $out
  '';

  # Plugins zsh (nixpkgs) — chemins de sourcing exacts.
  plug = name: src: file: { inherit name src file; };
in {
  config = mkIf (config.humanix.mainShell == "zsh") {
    environment.systemPackages = with pkgs; [
      nix-zsh-completions
      zsh-autosuggestions
    ];

    home-manager.users.${config.humanix.homeManagerUser} = { pkgs, config, lib, ...}: {
      home.packages = with pkgs; [ fastfetch shopt ];

      # Semage unique de l'historique Exegol dans ~/.zsh_history (idempotent).
      home.activation.exegolHistory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        FLAG="${config.home.homeDirectory}/.local/state/.exegol-history-seeded"
        if [ ! -f "$FLAG" ]; then
          mkdir -p "$(dirname "$FLAG")"
          cat ${exegolHistory} >> "${config.home.homeDirectory}/.zsh_history" 2>/dev/null || true
          touch "$FLAG"
        fi
      '';

      # Multiplexeur terminal : zellij démarre à l'ouverture du terminal.
      programs.zellij = {
        enable = true;
        enableZshIntegration = true;
        settings = {
          theme = "mrrobot";
          themes.mrrobot = {
            fg = "#00ff41"; bg = "#0a0f0a"; black = "#0a0f0a";
            red = "#ff2b2b"; green = "#00ff41"; yellow = "#ffb000";
            blue = "#00b32d"; magenta = "#39ff14"; cyan = "#00ff87";
            white = "#d4ffd4"; orange = "#ff2b2b";
          };
          pane_frames = false;
          simplified_ui = true;
        };
      };

      # fzf (fuzzy finder) : Ctrl-R historique, Ctrl-T fichiers, + moteur de fzf-tab.
      programs.fzf = {
        enable = true;
        enableZshIntegration = true;
        defaultOptions = [
          "--height 40%" "--layout=reverse" "--border"
          "--color=fg:#00cc33,bg:-1,hl:#00ff41,fg+:#00ff41,bg+:#123312,hl+:#39ff14"
          "--color=info:#00d38a,prompt:#00ff41,pointer:#ff2b2b,marker:#39ff14,spinner:#00d38a"
        ];
      };

      # Prompt Starship (informatif + vert) : configuré dans modules/dev/starship.

      programs.zsh = {
        enable = true;

        # Historique agrandi (pour cohabiter avec l'historique Exegol semé).
        history = {
          path = "${config.home.homeDirectory}/.zsh_history";
          size = 100000;
          save = 100000;
          expireDuplicatesFirst = true;
          ignoreDups = true;
          ignoreSpace = true;
          share = true;
        };

        setOptions = [ "INC_APPEND_HISTORY" "HIST_FCNTL_LOCK" "HIST_IGNORE_ALL_DUPS" ];

        enableCompletion = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = false;   # remplacé par fast-syntax-highlighting

        # Plugins « top » (nixpkgs, pas de clone runtime). Ordre : autopair,
        # fzf-tab (après compinit), you-should-use, fast-syntax-highlighting
        # (avant-dernier), history-substring-search (dernier, bind touches).
        plugins = [
          (plug "zsh-autopair" pkgs.zsh-autopair "share/zsh/zsh-autopair/autopair.zsh")
          (plug "fzf-tab" pkgs.zsh-fzf-tab "share/fzf-tab/fzf-tab.plugin.zsh")
          (plug "you-should-use" pkgs.zsh-you-should-use "share/zsh/plugins/you-should-use/you-should-use.plugin.zsh")
          (plug "fast-syntax-highlighting" pkgs.zsh-fast-syntax-highlighting "share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh")
          (plug "zsh-history-substring-search" pkgs.zsh-history-substring-search "share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.plugin.zsh")
        ];

        shellAliases = {
          shopt = "/run/current-system/sw/bin/shopt";
          nrs = "sudo nixos-rebuild switch --flake $HOME/nixos#Humanix";
          nrt = "sudo nixos-rebuild dry-build --flake $HOME/nixos#Humanix";
          nru = "sudo nix flake update --flake $HOME/nixos && sudo nixos-rebuild switch --flake $HOME/nixos#Humanix";
          nrgc = "sudo nix-collect-garbage --delete-older-than 14d && nix-collect-garbage -d";
          conky-reload = "pkill -9 conky 2>/dev/null; sleep 1; for c in monitor host clock cal cyber veille2; do conky -d -c $HOME/.config/conky/haxos-$c.conf; done";
          # Exegol : raccourcis usuels (image free).
          exe = "exegol";
          exe-start = "exegol start free";
        };

        completionInit = ''
          zstyle :compinstall filename "$HOME/.zshrc"
          autoload -U +X bashcompinit && bashcompinit
          autoload -U +X compinit && compinit
          # fzf-tab : rendu + preview vert
          zstyle ':completion:*' menu no
          zstyle ':fzf-tab:*' fzf-flags --color=fg:#00cc33,hl:#00ff41,fg+:#00ff41,bg+:#123312,hl+:#39ff14
          zstyle ':fzf-tab:*' use-fzf-default-opts yes
        '';

        initContent = ''
          bindkey -e
          # Recherche d'historique par sous-chaîne (flèches haut/bas).
          bindkey '^[[A' history-substring-search-up
          bindkey '^[[B' history-substring-search-down
          bindkey '^P' history-substring-search-up
          bindkey '^N' history-substring-search-down

          # Navigation mots (Ctrl+←/→) + Home/End/Suppr.
          bindkey "^[[1;5C" forward-word
          bindkey "^[[1;5D" backward-word
          bindkey "\e[1~" beginning-of-line
          bindkey "\e[4~" end-of-line
          bindkey "\e[3~" delete-char
          bindkey "\e[H" beginning-of-line
          bindkey "\e[F" end-of-line

          source ~/.bash_aliases 2>/dev/null || true
          if [[ -n "$ZELLIJ" ]]; then fastfetch || true; fi
        '';
      };
    };
  };
}
