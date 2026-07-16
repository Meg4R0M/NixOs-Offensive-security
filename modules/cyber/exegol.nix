# ─────────────────────────────────────────────────────────────────────────────
# Humanix · Exegol — environnement de pentest conteneurisé (image free)
# ─────────────────────────────────────────────────────────────────────────────
# https://exegol.com — wrapper Python qui orchestre des conteneurs Docker pleins
# d'outils offensifs, isolés et jetables. Image `free` = librement disponible
# (les images full/ad/web nécessitent un compte).
#
# L'image se tire au runtime (Docker, réseau) : après switch, lancer une fois
#   exegol install free      # tire l'image free
#   exegol start free        # démarre/entre dans le conteneur
# (aliases zsh `exe` / `exe-start` fournis par le module shell).
{ lib, pkgs, config, ... }:
let
  cfg = config.humanix.exegol;
in {
  options.humanix.exegol.enable = lib.mkEnableOption
    "Exegol — environnement pentest Docker (image free)";

  config = lib.mkIf cfg.enable {
    # ⚠️ exegol de nixpkgs KO sur python3.14 (chaîne supabase) :
    #  - pyiceberg pinne rich<15 (nixpkgs a 15) + un test io/pyarrow cassé ;
    #  - exegol pinne pydantic~=2.12 (nixpkgs a 2.13) et d'autres versions.
    # Overlay : réparer pyiceberg (relax rich + skip test) ; exegol : relax total.
    nixpkgs.overlays = [
      (final: prev: {
        pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
          (pyfinal: pyprev: {
            pyiceberg = pyprev.pyiceberg.overridePythonAttrs (o: {
              pythonRelaxDeps = (o.pythonRelaxDeps or [ ]) ++ [ "rich" ];
              doCheck = false;
            });
          })
        ];
      })
    ];

    environment.systemPackages = [
      (pkgs.exegol.overridePythonAttrs (o: { pythonRelaxDeps = true; }))
    ];

    # Exegol pilote Docker (l'user est déjà dans le groupe docker via
    # pentest-helpers). mkDefault : ne casse pas si docker est déjà activé.
    virtualisation.docker.enable = lib.mkDefault true;
  };
}
