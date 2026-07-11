{ pkgs, ... }:
let
  # rev PINNÉ obligatoire (l'éval channels est pure, pas de ref mutable)
  claude = (builtins.getFlake
    "github:Reginleif88/claude-cowork-nix/5018f7912405c1559314f56bc587ee6318d60132"
  ).packages.${pkgs.stdenv.hostPlatform.system}.default;

  claudeDesktop = pkgs.makeDesktopItem {
    name = "claude-desktop";
    desktopName = "Claude";
    exec = "${claude}/bin/claude-desktop %u";   # adapte si le binaire a un autre nom
    icon = "claude-desktop";                     # si l'icône manque, c'est cosmétique
    categories = [ "Network" "Utility" ];
    mimeTypes = [ "x-scheme-handler/claude" ];   # retour OAuth (login)
  };

in {
  environment.systemPackages = [ claude claudeDesktop ];
}
