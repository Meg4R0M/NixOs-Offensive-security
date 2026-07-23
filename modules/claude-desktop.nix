{ pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  claudePkgs = inputs.claude.packages.${system};
  asarTool = claudePkgs.asar-tool;

  # --- Fix boucle de login OAuth --------------------------------------------
  # L'app officielle Linux (1.20186.x, repackagée par Reginleif88) n'appelle
  # PAS requestSingleInstanceLock et n'a pas de handler `second-instance`. Le
  # callback `claude://login/...?code=...` lance donc une instance neuve au lieu
  # d'être forwardé à celle qui détient le code_verifier PKCE → handleDeepLink
  # (câblé sur second-instance/open-url) n'est jamais déclenché → boucle infinie.
  #
  # L'app écoute déjà `app.on("open-url", ...)` (chemin macOS) qui dispatche
  # l'URL. On préfixe donc au main un shim qui : (1) prend le lock single-
  # instance, (2) sur second-instance / argv au cold-start, ré-émet l'URL via
  # `open-url` — événement que l'app sait déjà traiter. Ne dépend que d'API
  # Electron standard → robuste aux màj. Voir memory claude-desktop-login-loop.
  singleInstanceShim = pkgs.writeText "single-instance-shim.js" ''
    ;(function () {
      const { app } = require('electron');
      if (!app.requestSingleInstanceLock()) { app.quit(); return; }
      const feed = function (argv) {
        const u = (argv || []).find(function (a) {
          return typeof a === 'string' && a.startsWith('claude://');
        });
        if (u) app.emit('open-url', { preventDefault: function () {} }, u);
      };
      app.on('second-instance', function (_e, argv) { feed(argv); });
      app.whenReady().then(function () { feed(process.argv); });
    })();
  '';

  # Injection dans l'app.asar : le buildPhase de claude-app finit par
  # `runHook postBuild` APRÈS le `asar pack`, et l'installPhase copie l'asar de
  # cwd → on ré-extrait, on préfixe le shim au `main`, on re-pack.
  patchedApp = claudePkgs.claude-app.overrideAttrs (old: {
    postBuild = (old.postBuild or "") + ''
      echo "[humanix] patches app.asar (single-instance + SDK binary path)"
      ${asarTool}/bin/asar-tool extract app.asar si-ex

      # Patch A : shim single-instance préfixé au main (fix boucle login).
      MAIN=$(${pkgs.python3}/bin/python3 -c 'import json;print(json.load(open("si-ex/package.json"))["main"])')
      echo "  main = $MAIN"
      { cat ${singleInstanceShim}; cat "si-ex/$MAIN"; } > "si-ex/$MAIN.new"
      mv "si-ex/$MAIN.new" "si-ex/$MAIN"

      # Patch B : le SDK Claude Code (sessions Code + serveurs MCP) spawn un
      # binaire natif calculé comme <resourcesPath>/../Helpers/disclaimer, qui
      # n'existe pas chez nix (electron sans les Helpers bundlés) → ENOENT
      # "native binary not found". Le CCD LOCAL override (patch 14) ne couvre
      # PAS ce chemin. On fait honorer CLAUDE_CODE_LOCAL_BINARY à cette fonction.
      TARGET=$(grep -rl 'Helpers","disclaimer' si-ex/.vite/build/ | head -1)
      echo "  disclaimer chunk = $TARGET"
      ${pkgs.perl}/bin/perl -i -pe \
        's{return (\w+\.join\(\w+,"Helpers","disclaimer"\))}{return process.env.CLAUDE_CODE_LOCAL_BINARY||$1}g' \
        "$TARGET"
      grep -q 'CLAUDE_CODE_LOCAL_BINARY||' "$TARGET" \
        || { echo "ERROR: patch B (SDK binary path) n'a pas pris"; exit 1; }

      rm -f app.asar
      ${asarTool}/bin/asar-tool pack si-ex app.asar
    '';
  });

  # Swap de l'app patchée dans la closure du wrapper FHS `default` (qui garde
  # Cowork + MCP), sans avoir à reconstruire tout le wrapper.
  claudeUnwrapped = pkgs.replaceDependency {
    drv = claudePkgs.default;
    oldDependency = claudePkgs.claude-app;
    newDependency = patchedApp;
  };

  # La feature Claude Code de l'app cherche son binaire natif ; sur `default`
  # (claudeCodePackage=null) l'env CLAUDE_CODE_LOCAL_BINARY n'est jamais posé
  # → "Claude Code native binary not found". On pointe vers pkgs.claude-code.
  claude = pkgs.symlinkJoin {
    name = "claude-desktop";
    paths = [ claudeUnwrapped ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/claude-desktop \
        --set-default CLAUDE_CODE_LOCAL_BINARY ${pkgs.claude-code}/bin/claude
    '';
  };

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
