{ lib, pkgs, config, ... }:
# Polices custom déposées par l'utilisateur : Robotastic (conky) et
# Zekton (titres de fenêtres + barre du haut). Packagées et installées
# système-wide pour fontconfig.
let
  customFonts = pkgs.stdenvNoCC.mkDerivation {
    pname = "athena-custom-fonts";
    version = "1.0";
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      install -Dm644 ${./fonts/robotastic.ttf}     $out/share/fonts/truetype/robotastic.ttf
      install -Dm644 ${./fonts/Zekton-Regular.otf} $out/share/fonts/opentype/Zekton-Regular.otf
      runHook postInstall
    '';
    meta.description = "Polices Robotastic + Zekton (Athena rice).";
  };
in
{
  config = lib.mkIf config.athena.baseConfiguration {
    fonts.packages = [ customFonts ];
  };
}
