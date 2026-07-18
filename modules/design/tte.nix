# ─────────────────────────────────────────────────────────────────────────────
# Humanix · TerminalTextEffects (TTE) — eye-candy terminal ANSI
# ─────────────────────────────────────────────────────────────────────────────
# `tte` (nixpkgs) applique des effets animés à du texte (l'effet joue 1×, puis
# laisse le texte final en place -> se pipe sans casser un script). 100% ANSI,
# aucun risque (sortie terminal, ni boot ni login graphique).
#
# On l'expose de façon CIBLÉE (animer chaque terminal = gonflant + latence) :
#  - bannière login révélée 1×/session (flag XDG_RUNTIME_DIR) au 1er shell ;
#  - `hx-intro [effet]`  : logo HUMANIX figlet animé (showcase, à lancer) ;
#  - `hxfetch [effet]`   : fastfetch révélé en animation (garde ses couleurs) ;
#  - le binaire `tte` reste dispo pour piper à la main.
{ lib, pkgs, config, ... }:
let
  cfg   = config.humanix;
  tteOn = cfg.aesthetic.tte.enable;
  user  = cfg.homeManagerUser;

  tte    = "${pkgs.terminaltexteffects}/bin/tte";
  figlet = "${pkgs.figlet}/bin/figlet";
  green  = "00ff41 39ff14 00cc33";   # gradient final vert phosphore

  # Logo HUMANIX + greeting, révélé par l'effet passé en 1er arg (défaut beams).
  # Repli figlet nu si tte échoue (jamais bloquant).
  hxIntro = pkgs.writeShellScriptBin "hx-intro" ''
    eff="''${1:-beams}"
    { ${figlet} -f slant -w 160 HUMANIX; \
      printf '\n   ACCES RESTREINT  //  la bidouille est reine\n'; } \
      | ${tte} "$eff" --final-gradient-stops ${green} 2>/dev/null \
      || ${figlet} -f slant HUMANIX
  '';

  # fastfetch révélé en animation, en PRÉSERVANT ses couleurs.
  # --existing-color-handling = option GLOBALE -> AVANT le nom de l'effet.
  # --logo none : le logo ASCII coloré de fastfetch fait planter le parser ANSI
  # de TTE (ValueError sur une séquence couleur) -> on retire le logo, l'info
  # colorée animée reste. Repli fastfetch nu si tte échoue.
  hxFetch = pkgs.writeShellScriptBin "hxfetch" ''
    eff="''${1:-slide}"
    ${pkgs.fastfetch}/bin/fastfetch --logo none \
      | ${tte} --existing-color-handling always "$eff" 2>/dev/null \
      || ${pkgs.fastfetch}/bin/fastfetch
  '';
in
{
  options.humanix.aesthetic.tte.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "TerminalTextEffects : bannière login animée (1×/session) + commandes hx-intro / hxfetch.";
  };

  config = lib.mkIf tteOn {
    environment.systemPackages = [ pkgs.terminaltexteffects pkgs.figlet hxIntro hxFetch ];

    # Bannière révélée UNE fois par session (flag dans XDG_RUNTIME_DIR, effacé au
    # logout) au 1er shell interactif -> pas à chaque terminal. mkAfter = en fin
    # d'init zsh (PATH prêt), juste avant le prompt. Jamais bloquant (|| true).
    home-manager.users.${user}.programs.zsh.initContent = lib.mkAfter ''
      if [[ -o interactive && -n "$XDG_RUNTIME_DIR" && ! -e "$XDG_RUNTIME_DIR/.hx-banner" ]]; then
        : > "$XDG_RUNTIME_DIR/.hx-banner"
        hx-intro decrypt 2>/dev/null || true
      fi
    '';
  };
}
