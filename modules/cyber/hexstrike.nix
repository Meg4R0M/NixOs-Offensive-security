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

  # Alias : noms de binaires attendus par HexStrike mais présents sous un autre
  # nom (outils déjà là) → `which <nom>` de HexStrike les trouve enfin.
  toolAliases = pkgs.runCommand "hexstrike-aliases" { } ''
    mkdir -p $out/bin
    ln -sf ${pkgs.metasploit}/bin/msfconsole     $out/bin/metasploit
    ln -sf ${pkgs.volatility3}/bin/vol           $out/bin/volatility3
    ln -sf ${pkgs.volatility3}/bin/vol           $out/bin/volatility
    ln -sf ${pkgs.theharvester}/bin/theHarvester $out/bin/theharvester
    ln -sf ${pkgs.exploitdb}/bin/searchsploit    $out/bin/exploit-db
    ln -sf ${pkgs.zap}/bin/zap                    $out/bin/zaproxy
    ln -sf ${pkgs.ropgadget}/bin/ROPgadget       $out/bin/ropgadget
    ln -sf ${pkgs.scoutsuite}/bin/scout          $out/bin/scout-suite
    ln -sf ${pkgs.one_gadget}/bin/one_gadget     $out/bin/one-gadget
    ln -sf ${pkgs.bulk_extractor}/bin/bulk_extractor $out/bin/bulk-extractor
    ln -sf ${pkgs.python3Packages.shodan}/bin/shodan $out/bin/shodan-cli
    ln -sf ${pkgs.python3Packages.censys}/bin/censys  $out/bin/censys-cli
    ln -sf ${pkgs.python3Packages.pwntools}/bin/pwn    $out/bin/pwntools
    ln -sf ${pkgs.samba}/bin/rpcclient           $out/bin/rpcclient
    ln -sf ${pkgs.sleuthkit}/bin/fls             $out/bin/sleuthkit
  '';

  # Outils "false" réellement absents mais dispo dans nixpkgs → on maximise.
  extraTools = with pkgs; [
    binutils bulk_extractor clair hashcat-utils httpie kube-bench
    nbtscan one_gadget outguess pwninit qsreplace ropgadget scoutsuite steghide
    terrascan uro xxd zsteg
    python3Packages.shodan python3Packages.censys
  ];

  # PATH runtime : chromedriver (selenium), wordlists, alias + outils ajoutés,
  # + l'arsenal système/paquets user (via le wrapper).
  runtimePath = lib.makeBinPath ([ pkgs.chromium pkgs.chromedriver pkgs.seclists toolAliases ] ++ extraTools);

  server = pkgs.writeShellScriptBin "hexstrike-server" ''
    export PATH="${runtimePath}:/run/current-system/sw/bin:$HOME/.nix-profile/bin:$PATH"
    export HEXSTRIKE_PORT="''${HEXSTRIKE_PORT:-8888}"
    exec ${pyEnv}/bin/python3 ${patched}/hexstrike_server.py "$@"
  '';

  mcpClient = pkgs.writeShellScriptBin "hexstrike-mcp" ''
    exec ${pyEnv}/bin/python3 ${patched}/hexstrike_mcp.py "$@"
  '';

  # Helper : enregistre HexStrike auprès de Claude Code (CLI) ET Claude Desktop
  # (app). À lancer une fois. Les deux utilisent l'abonnement (aucune API).
  setup = pkgs.writeShellScriptBin "hexstrike-setup-claude" ''
    # 1) Claude Code (CLI), si présent
    if command -v claude >/dev/null 2>&1; then
      claude mcp add hexstrike-ai -- ${mcpClient}/bin/hexstrike-mcp --server http://127.0.0.1:8888 \
        && echo "✓ HexStrike ajouté à Claude Code (CLI)" \
        || echo "· (déjà présent dans Claude Code, ou erreur bénigne)"
    else
      echo "· claude CLI absent (sera là après le prochain switch)."
    fi
    # 2) Claude Desktop (app) : merge dans claude_desktop_config.json
    CFG="$HOME/.config/Claude/claude_desktop_config.json"
    mkdir -p "$(dirname "$CFG")"
    [ -f "$CFG" ] || echo '{}' > "$CFG"
    ${pkgs.python3}/bin/python3 - "$CFG" <<'PY'
import json, sys
p = sys.argv[1]
try:
    d = json.load(open(p))
except Exception:
    d = {}
d.setdefault("mcpServers", {})["hexstrike-ai"] = {
    "command": "${mcpClient}/bin/hexstrike-mcp",
    "args": ["--server", "http://127.0.0.1:8888"],
    "timeout": 300,
}
json.dump(d, open(p, "w"), indent=2)
print("✓ HexStrike ajouté à Claude Desktop:", p)
PY
    echo "→ Redémarre Claude Desktop (ou lance 'claude') pour charger HexStrike."
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
    # ecdsa (dep transitive d'outils cloud/OSINT) marqué insecure (CVE timing
    # mineur) — autorisé pour ne pas perdre checkov/shodan/censys.
    nixpkgs.config.permittedInsecurePackages = [ "python3.14-ecdsa-0.19.2" ];

    # claude-code = le CLI `claude` (client MCP idéal, pilote le pentest en
    # terminal via l'abonnement — aucune API). En plus de Claude Desktop.
    environment.systemPackages = [ server mcpClient setup pkgs.claude-code ];

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
