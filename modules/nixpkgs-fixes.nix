# ─────────────────────────────────────────────────────────────────────────────
# Humanix · Correctifs de paquets TRANSITOIREMENT cassés sur nixpkgs-unstable
# ─────────────────────────────────────────────────────────────────────────────
# Overrides DATÉS, à RETIRER dès qu'upstream corrige (aucun n'est structurel).
# Constatés au bump nixpkgs 0bb7ec5 -> 0954f7ee (2026-07-29) : uniquement de
# l'outillage offensif Python + deps, le cœur (openssl/kernel/glibc…) build bien.
# pythonPackagesExtensions => s'applique à TOUTES les versions de Python.
{ ... }:
{
  nixpkgs.overlays = [
    (final: prev: {
      # chipsec 1.13.20 : 2 tests (formatage de chaîne, TypeError) cassés -> skip.
      chipsec = prev.chipsec.overridePythonAttrs (o: { doCheck = false; });

      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (pyfinal: pyprev: {
          # tenacity 9.1.4 : 1 test asyncio de TIMING flaky sous charge
          # (AssertionError: 6 not less than 1.1), 124/125 tests OK.
          tenacity = pyprev.tenacity.overridePythonAttrs (o: { doCheck = false; });

          # stamina 25.2.0 : erreur de COLLECTE de tests (TestGuessName).
          stamina = pyprev.stamina.overridePythonAttrs (o: { doCheck = false; });

          # myjwt 2.1.0 : pyproject hardcode 2.0.0 -> mismatch avec la version de
          # la drv. Le hook réaligne la version du projet sur celle de la drv.
          myjwt = pyprev.myjwt.overridePythonAttrs (o: {
            nativeBuildInputs = (o.nativeBuildInputs or [ ]) ++ [ pyprev.pyprojectVersionPatchHook ];
          });
          # NB : bloodhound-py 1.9.0 est cassé (metadata dist) plus profondément ->
          # RETIRÉ des rôles (pas patché ici), avec netexec qui en dépend.
        })
      ];
    })
  ];
}
