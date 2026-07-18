# ─────────────────────────────────────────────────────────────────────────────
# Humanix · KittySploit — framework d'exploitation Python + serveur MCP
# ─────────────────────────────────────────────────────────────────────────────
# https://github.com/SIA-IOTechnology/Kittysploit-framework — framework offensif
# modulaire (façon Metasploit) : modules/exploits, payloads Zig, KittyProxy, et
# surtout un SERVEUR MCP natif (kittymcp_server.py, stdio) → pilotable par Claude
# Code/Desktop en abonnement, comme HexStrike (AUCUNE clé API). Ollama optionnel.
#
# Pourquoi un buildFHSEnv et pas une dérivation Nix pure : c'est un framework
# IMPUR (venv + pip, marketplace de modules, auto-update git, compilation Zig au
# runtime) qui s'attend à un FHS classique. On lui fournit donc un env FHS
# (python/pip/zig/git + libs) et il vit dans un dossier MUTABLE (~/.local/share).
#
# Jeune (créé 2025-10) → volontairement OPT-IN (enable OFF par défaut). 1er
# lancement : clone + venv + pip (réseau requis, ~1-2 min). Aucun service, aucun
# port ouvert : le MCP est un process stdio lancé à la demande par Claude.
{ lib, pkgs, config, ... }:
let
  cfg = config.humanix.ai.kittysploit;
  inherit (lib) mkEnableOption mkIf;

  repo = "https://github.com/SIA-IOTechnology/Kittysploit-framework";

  # Bootstrap exécuté DANS l'env FHS : clone si absent, venv + deps si absent,
  # puis dispatch console / mcp / update selon KITTY_MODE.
  bootScript = pkgs.writeShellScript "kittysploit-boot" ''
    set -e
    DIR="$HOME/.local/share/kittysploit"
    export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    export GIT_SSL_CAINFO="$SSL_CERT_FILE"
    export PIP_DISABLE_PIP_VERSION_CHECK=1

    if [ ! -d "$DIR/.git" ]; then
      echo "[*] Premier lancement — clonage de KittySploit dans $DIR ..."
      mkdir -p "$(dirname "$DIR")"
      git clone --depth 1 ${repo} "$DIR"
    fi
    cd "$DIR"
    if [ ! -x .venv/bin/python ]; then
      echo "[*] Setup venv + dépendances (réseau requis, ~1-2 min)..."
      python3 -m venv .venv
      .venv/bin/pip install --upgrade pip wheel setuptools
      [ -f requirements.txt ] && .venv/bin/pip install -r requirements.txt || true
      { [ -f pyproject.toml ] || [ -f setup.py ]; } && .venv/bin/pip install -e . || true
    fi

    case "''${KITTY_MODE:-console}" in
      mcp)
        # Charte requise pour un démarrage stdio non-interactif. Le consentement
        # aux opérations « dangereuses » reste à activer par l'user (env
        # KITTYMCP_DANGEROUS_CONSENT=1) — non forcé ici volontairement.
        export KITTYSPLOIT_MCP_ACCEPT_CHARTER=1
        export KITTYMCP_ROLES="''${KITTYMCP_ROLES:-operator}"
        exec .venv/bin/python kittymcp_server.py --transport stdio "$@" ;;
      update)
        echo "[*] Mise à jour (git pull + deps)..."
        git pull --ff-only && .venv/bin/pip install -e . || true ;;
      bootstrap)
        # clone + venv déjà faits ci-dessus -> on sort (préchauffage au login).
        echo "[*] KittySploit prêt (clone + venv OK)." ;;
      *)
        exec .venv/bin/python kittyconsole.py "$@" ;;
    esac
  '';

  # Env FHS : tout ce qu'il faut pour pip/wheels/venv + Zig + libs natives.
  kittyFHS = pkgs.buildFHSEnv {
    name = "kittysploit";
    targetPkgs = p: with p; [
      python3 python3.pkgs.pip python3.pkgs.virtualenv
      git gcc gnumake pkg-config zig
      zlib openssl libffi ncurses readline libpcap
      stdenv.cc.cc.lib cacert curl
    ];
    runScript = "${bootScript}";
  };

  # Commandes exposées (kittysploit = console via l'FHS ; les autres = modes).
  kittyMcp = pkgs.writeShellScriptBin "kittysploit-mcp" ''
    KITTY_MODE=mcp exec ${kittyFHS}/bin/kittysploit "$@"
  '';
  kittyUpdate = pkgs.writeShellScriptBin "kittysploit-update" ''
    KITTY_MODE=update exec ${kittyFHS}/bin/kittysploit
  '';

  # Enregistre le MCP KittySploit auprès de Claude Code (CLI) + Claude Desktop.
  # Même principe que hexstrike-setup-claude : stdio, piloté par l'abonnement.
  kittySetup = pkgs.writeShellScriptBin "kittysploit-setup-claude" ''
    if command -v claude >/dev/null 2>&1; then
      claude mcp add kittysploit -- ${kittyMcp}/bin/kittysploit-mcp \
        && echo "✓ KittySploit ajouté à Claude Code (CLI)" \
        || echo "· (déjà présent dans Claude Code, ou erreur bénigne)"
    else
      echo "· claude CLI absent (sera là après le prochain switch)."
    fi
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
d.setdefault("mcpServers", {})["kittysploit"] = {
    "command": "${kittyMcp}/bin/kittysploit-mcp",
    "timeout": 300,
}
json.dump(d, open(p, "w"), indent=2)
print("✓ KittySploit ajouté à Claude Desktop:", p)
PY
    echo "→ Au 1er appel, KittySploit se clone + installe (réseau, ~1-2 min)."
    echo "→ Redémarre Claude Desktop (ou lance 'claude') pour le charger."
  '';

  # Autostart au login (idempotent) : bootstrap (clone+venv, best-effort si pas de
  # réseau) PUIS enregistrement du MCP auprès de Claude (Code + Desktop). Rend
  # KittySploit « prêt par défaut » sans étape manuelle.
  kittyAutostart = pkgs.writeShellScript "kittysploit-autostart" ''
    KITTY_MODE=bootstrap ${kittyFHS}/bin/kittysploit >/dev/null 2>&1 || true
    ${kittySetup}/bin/kittysploit-setup-claude >/dev/null 2>&1 || true
  '';
in {
  options.humanix.ai.kittysploit = {
    enable = mkEnableOption
      "KittySploit — framework d'exploitation Python + serveur MCP (piloté par Claude, sans API). Jeune : opt-in";

    autostart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Au login (service systemd user oneshot) : bootstrap (clone + venv) PUIS
        enregistrement du MCP auprès de Claude (Code + Desktop) -> KittySploit
        prêt par défaut, sans étape manuelle. false = le faire à la main via
        `kittysploit` (1er run) + `kittysploit-setup-claude`.
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ kittyFHS kittyMcp kittyUpdate kittySetup ];

    # « Démarré par défaut » : au login, bootstrap + enregistrement MCP Claude.
    # oneshot idempotent (le clone/venv se skippe une fois fait ; l'enregistrement
    # gère « déjà présent »). Best-effort réseau (|| true dans le script).
    systemd.user.services.kittysploit-setup = mkIf cfg.autostart {
      description = "KittySploit — bootstrap + enregistrement du MCP auprès de Claude";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${kittyAutostart}";
        # PATH pour que le script trouve `claude` (Claude Code CLI) s'il est là.
        Environment = "PATH=/run/current-system/sw/bin:/run/wrappers/bin";
      };
    };
  };
}
