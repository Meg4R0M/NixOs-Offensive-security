{ pkgs, inputs, ... }:
let
  # Vient du flake (inputs.claude), plus de getFlake impur.
  claude = inputs.claude.packages.${pkgs.stdenv.hostPlatform.system}.default;

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
