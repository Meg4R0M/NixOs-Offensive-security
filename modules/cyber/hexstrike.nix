# ─────────────────────────────────────────────────────────────────────────────
# Humanix · HexStrike AI — serveur MCP d'outils offensifs
# ─────────────────────────────────────────────────────────────────────────────
# https://github.com/0x4m4/hexstrike-ai — 2 scripts Python :
#   • hexstrike_server.py : API Flask (:8888) qui exécute les outils EN LOCAL
#     (subprocess, outils résolus par PATH → réutilise l'arsenal Humanix).
#   • hexstrike_mcp.py    : serveur MCP (stdio) exposant ~150 outils, parle à l'API.
#
# ⇒ Piloté par Claude Code / Gemini CLI via MCP : le raisonnement LLM se fait
#    CÔTÉ CLIENT (ton abonnement) → AUCUNE clé API, AUCUN surcoût. PAS de Docker.
#
# Débrayable : humanix.ai.hexstrike.enable (défaut OFF ; mis à true dans
# configuration.nix). Sécurité : le serveur exécute du shell arbitraire → on
# patche le bind en 127.0.0.1 et on N'OUVRE PAS le port 8888 dans le firewall.
{ lib, pkgs, config, ... }:
let
  cfg = config.humanix.ai.hexstrike;
  inherit (lib) mkEnableOption mkOption types mkIf optionals;

  src = pkgs.fetchFromGitHub {
    owner = "0x4m4";
    repo = "hexstrike-ai";
    rev = "9b8c780f324ce5145a322bfa23c98886f8424ba3";
    sha256 = "0maxjmccva139sjma892a2jhdyp24g7308wm2a42fkslm2vg6i2q";
  };

  # Défense en profondeur : bind localhost au lieu de 0.0.0.0.
  patched = pkgs.runCommand "hexstrike-ai-src" { } ''
    cp -r ${src} $out
    chmod -R +w $out
    substituteInPlace $out/hexstrike_server.py \
      --replace 'host="0.0.0.0"' 'host="127.0.0.1"'
  '';

  # Tests de inline-snapshot cassés sur ce nixpkgs (checkInput de fastapi, tiré
  # par mitmproxy) → on les saute pour débloquer la chaîne.
  python = pkgs.python312.override {
    packageOverrides = _pyself: pysuper: {
      inline-snapshot = pysuper.inline-snapshot.overridePythonAttrs (_: { doCheck = false; });
    };
  };
  pyEnv = python.withPackages (ps: with ps; [
    flask requests psutil beautifulsoup4 selenium aiohttp mitmproxy mcp bcrypt
  ] ++ optionals cfg.binaryAnalysis [ pwntools angr ]);

  # PATH runtime : chromedriver (selenium, au lieu de webdriver-manager),
  # wordlists, + l'arsenal système et les paquets user.
  runtimePath = lib.makeBinPath [ pkgs.chromium pkgs.chromedriver pkgs.seclists ];

  server = pkgs.writeShellScriptBin "hexstrike-server" ''
    export PATH="${runtimePath}:/run/current-system/sw/bin:$HOME/.nix-profile/bin:$PATH"
    export HEXSTRIKE_PORT="''${HEXSTRIKE_PORT:-8888}"
    exec ${pyEnv}/bin/python3 ${patched}/hexstrike_server.py "$@"
  '';

  mcpClient = pkgs.writeShellScriptBin "hexstrike-mcp" ''
    exec ${pyEnv}/bin/python3 ${patched}/hexstrike_mcp.py "$@"
  '';

  # Helper : enregistre HexStrike auprès de Claude Code (à lancer une fois).
  setup = pkgs.writeShellScriptBin "hexstrike-setup-claude" ''
    set -e
    claude mcp add hexstrike-ai -- ${mcpClient}/bin/hexstrike-mcp --server http://127.0.0.1:8888
    echo "✓ HexStrike ajouté à Claude Code. Démarre le serveur (hexstrike-server ou"
    echo "  le service systemd user), lance 'claude' et demande un scan."
  '';
in {
  options.humanix.ai.hexstrike = {
    enable = mkEnableOption
      "HexStrike AI — serveur MCP d'outils pentest, piloté par Claude Code (sans API, sans Docker)";
    autostart = mkOption {
      type = types.bool;
      default = true;
      description = "Démarre le serveur d'outils (127.0.0.1:8888) au login (service systemd user).";
    };
    binaryAnalysis = mkOption {
      type = types.bool;
      default = false;
      description = "Ajoute pwntools + angr (endpoints d'analyse binaire ; closure lourde).";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ server mcpClient setup ];

    systemd.user.services.hexstrike-server = mkIf cfg.autostart {
      description = "HexStrike AI — API d'outils pentest (127.0.0.1:8888)";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${server}/bin/hexstrike-server --port 8888";
        Restart = "on-failure";
        RestartSec = 3;
      };
    };
  };
}
