# ─────────────────────────────────────────────────────────────────────────────
# Humanix · DefectDojo — dashboard bug bounty + serveur MCP (piloté par Claude)
# ─────────────────────────────────────────────────────────────────────────────
# DefectDojo (django-DefectDojo) via virtualisation.oci-containers (backend docker).
# 7 services : postgres, valkey (broker), initializer (one-shot), uwsgi (web),
# celeryworker, celerybeat, nginx (exposé 127.0.0.1:8080). + le serveur MCP
# jamiesonio/defectdojo-mcp (packagé) pour que Claude Code/Desktop gère les
# findings (get/search/update/notes) — raisonnement côté abonnement, AUCUNE API.
#
# Secrets (clés Django/AES, mdp DB, mdp admin) générés à l'activation dans un
# fichier root hors du store (SANS rapport avec le login → aucun risque lockout).
# Import des scans : `dd-import nuclei|nmap <fichier> <product> <engagement>`.
# Setup Claude : `defectdojo-setup-claude`. Débrayable : humanix.ai.defectdojo.enable.
{ lib, pkgs, config, ... }:
let
  cfg = config.humanix.ai.defectdojo;
  inherit (lib) mkEnableOption mkOption types mkIf;

  ddDjangoImage = "defectdojo/defectdojo-django:${cfg.tag}";
  ddNginxImage  = "defectdojo/defectdojo-nginx:${cfg.tag}";
  pgImage       = "postgres:16-alpine";
  valkeyImage   = "valkey/valkey:8-alpine";

  ddNet      = "defectdojo";
  secretsEnv = "/var/lib/defectdojo/secrets.env";
  net        = [ "--network=${ddNet}" ];
  waitPg     = [ "defectdojo-postgres:5432" "-t" "30" "--" ];

  djangoCommonEnv = {
    DD_DEBUG = "False";
    DD_DJANGO_METRICS_ENABLED = "False";
    DD_ALLOWED_HOSTS = "*";
    DD_CELERY_BROKER_URL = "redis://defectdojo-valkey:6379/0";
    DD_DATABASE_READINESS_TIMEOUT = "30";
  };

  # inline-snapshot (checkInput transitif de mcp→fastapi) a des tests cassés → skip.
  ddPython = pkgs.python312.override {
    packageOverrides = _self: super: {
      inline-snapshot = super.inline-snapshot.overridePythonAttrs (_: { doCheck = false; });
    };
  };
  # Serveur MCP DefectDojo (stdio) — wrap de l'API REST, aucune clé LLM.
  ddMcp = ddPython.pkgs.buildPythonApplication {
    pname = "defectdojo-mcp";
    version = "0.1.2";
    pyproject = true;
    src = pkgs.fetchFromGitHub {
      owner = "jamiesonio";
      repo = "defectdojo-mcp";
      rev = "379416fc08350e13fec5eb89099e8c549bf6f9ea";
      sha256 = "1yvbp3khvrrpjrakj71slsyap5v1bys93d05c5jahhaayndp60jd";
    };
    build-system = with ddPython.pkgs; [ setuptools wheel ];
    dependencies = with ddPython.pkgs; [ httpx mcp typer click ];
    doCheck = false;
  };

  # Récupère le token API + configure Claude Code (CLI) ET Claude Desktop.
  setup = pkgs.writeShellScriptBin "defectdojo-setup-claude" ''
    set -e
    PW=$(sudo ${pkgs.gnugrep}/bin/grep '^DD_ADMIN_PASSWORD=' ${secretsEnv} | cut -d= -f2)
    echo "· récupération du token API DefectDojo…"
    TOK=$(${pkgs.curl}/bin/curl -s -X POST http://127.0.0.1:8080/api/v2/api-token-auth/ \
      -H "Content-Type: application/json" \
      -d "{\"username\":\"admin\",\"password\":\"$PW\"}" | ${pkgs.jq}/bin/jq -r .token)
    if [ -z "$TOK" ] || [ "$TOK" = "null" ]; then
      echo "✗ token vide — DefectDojo n'est peut-être pas encore prêt (attends 1-2 min après le switch, puis relance)."; exit 1
    fi
    # Claude Code CLI
    if command -v claude >/dev/null 2>&1; then
      claude mcp add defectdojo \
        --env DEFECTDOJO_API_TOKEN="$TOK" --env DEFECTDOJO_API_BASE=http://127.0.0.1:8080 \
        -- ${ddMcp}/bin/defectdojo-mcp \
        && echo "✓ MCP defectdojo ajouté à Claude Code (CLI)" || echo "· (déjà présent ?)"
    fi
    # Claude Desktop
    CFG="$HOME/.config/Claude/claude_desktop_config.json"
    mkdir -p "$(dirname "$CFG")"; [ -f "$CFG" ] || echo '{}' > "$CFG"
    ${pkgs.python3}/bin/python3 - "$CFG" "$TOK" <<'PY'
import json, sys
p, tok = sys.argv[1], sys.argv[2]
try: d = json.load(open(p))
except Exception: d = {}
d.setdefault("mcpServers", {})["defectdojo"] = {
    "command": "${ddMcp}/bin/defectdojo-mcp",
    "env": {"DEFECTDOJO_API_TOKEN": tok, "DEFECTDOJO_API_BASE": "http://127.0.0.1:8080"},
}
json.dump(d, open(p, "w"), indent=2)
print("✓ MCP defectdojo ajouté à Claude Desktop:", p)
PY
    echo "→ Redémarre Claude Desktop (ou relance 'claude'). UI: http://127.0.0.1:8080 (admin / le mdp de ${secretsEnv})."
  '';

  # Import d'un scan nuclei/nmap dans DefectDojo (auto-crée product+engagement).
  ddImport = pkgs.writeShellScriptBin "dd-import" ''
    set -euo pipefail
    TOOL="''${1:?usage: dd-import <nuclei|nmap> <fichier> <product> <engagement>}"
    FILE="''${2:?fichier de rapport}"; PRODUCT="''${3:?nom product}"; ENG="''${4:?nom engagement}"
    case "$TOOL" in
      nuclei) ST="Nuclei Scan" ;; nmap) ST="Nmap Scan" ;;
      *) echo "tool inconnu (nuclei|nmap)"; exit 1 ;;
    esac
    TOK=$(sudo ${pkgs.gnugrep}/bin/grep '^DD_ADMIN_PASSWORD=' ${secretsEnv} | cut -d= -f2 \
      | { read -r PW; ${pkgs.curl}/bin/curl -s -X POST http://127.0.0.1:8080/api/v2/api-token-auth/ \
          -H "Content-Type: application/json" -d "{\"username\":\"admin\",\"password\":\"$PW\"}" \
          | ${pkgs.jq}/bin/jq -r .token; })
    ${pkgs.curl}/bin/curl -s -X POST http://127.0.0.1:8080/api/v2/import-scan/ \
      -H "Authorization: Token $TOK" \
      -F "scan_type=$ST" -F "file=@''${FILE}" \
      -F "product_name=''${PRODUCT}" -F "engagement_name=''${ENG}" \
      -F "auto_create_context=true" -F "active=true" -F "close_old_findings=false" \
      -F "scan_date=$(date +%F)" -F "minimum_severity=Info" | ${pkgs.jq}/bin/jq .
  '';
in {
  options.humanix.ai.defectdojo = {
    enable = mkEnableOption "DefectDojo — dashboard bug bounty (oci-containers) + MCP Claude";
    tag = mkOption {
      type = types.str;
      default = "latest";
      description = "Tag des images defectdojo-django/-nginx (même version pour les deux ; épingle en prod).";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.docker.enable = lib.mkDefault true;
    virtualisation.oci-containers.backend = "docker";

    # Secrets générés une fois (root, hors store).
    system.activationScripts.defectdojoSecrets.text = ''
      mkdir -p /var/lib/defectdojo && chmod 0700 /var/lib/defectdojo
      if [ ! -f ${secretsEnv} ]; then
        umask 0077
        SK=$(${pkgs.openssl}/bin/openssl rand -base64 48 | tr -d '\n=+/' | cut -c1-50)
        AK=$(${pkgs.openssl}/bin/openssl rand -base64 48 | tr -d '\n=+/' | cut -c1-32)
        PG=$(${pkgs.openssl}/bin/openssl rand -hex 24)
        AP=$(${pkgs.openssl}/bin/openssl rand -base64 24 | tr -d '\n=+/' | cut -c1-22)
        {
          echo "DD_SECRET_KEY=$SK"
          echo "DD_CREDENTIAL_AES_256_KEY=$AK"
          echo "POSTGRES_PASSWORD=$PG"
          echo "DD_DATABASE_URL=postgresql://defectdojo:$PG@defectdojo-postgres:5432/defectdojo"
          echo "DD_ADMIN_PASSWORD=$AP"
        } > ${secretsEnv}
        chmod 0600 ${secretsEnv}
      fi
    '';

    # Réseau docker dédié (DNS par nom de conteneur).
    systemd.services.init-defectdojo-network = {
      description = "Create defectdojo docker network";
      after = [ "docker.service" ]; requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      script = ''
        ${pkgs.docker}/bin/docker network inspect ${ddNet} >/dev/null 2>&1 \
          || ${pkgs.docker}/bin/docker network create ${ddNet}
      '';
    };

    virtualisation.oci-containers.containers = {
      defectdojo-postgres = {
        image = pgImage;
        environment = { PGDATA = "/var/lib/postgresql/data"; POSTGRES_DB = "defectdojo"; POSTGRES_USER = "defectdojo"; };
        environmentFiles = [ secretsEnv ];
        volumes = [ "defectdojo_postgres:/var/lib/postgresql/data" ];
        extraOptions = net ++ [ "--health-cmd=pg_isready -U defectdojo -d defectdojo" "--health-interval=10s" "--health-retries=5" ];
      };
      defectdojo-valkey = {
        image = valkeyImage;
        volumes = [ "defectdojo_redis:/data" ];
        extraOptions = net;
      };
      defectdojo-uwsgi = {
        image = ddDjangoImage;
        entrypoint = "/wait-for-it.sh";
        cmd = waitPg ++ [ "/entrypoint-uwsgi.sh" ];
        environment = djangoCommonEnv;
        environmentFiles = [ secretsEnv ];
        volumes = [ "defectdojo_media:/app/media" ];
        dependsOn = [ "defectdojo-postgres" "defectdojo-valkey" ];
        extraOptions = net;
      };
      defectdojo-celeryworker = {
        image = ddDjangoImage;
        entrypoint = "/wait-for-it.sh";
        cmd = waitPg ++ [ "/entrypoint-celery-worker.sh" ];
        environment = djangoCommonEnv;
        environmentFiles = [ secretsEnv ];
        volumes = [ "defectdojo_media:/app/media" ];
        dependsOn = [ "defectdojo-postgres" "defectdojo-valkey" ];
        extraOptions = net;
      };
      defectdojo-celerybeat = {
        image = ddDjangoImage;
        entrypoint = "/wait-for-it.sh";
        cmd = waitPg ++ [ "/entrypoint-celery-beat.sh" ];
        environment = djangoCommonEnv;
        environmentFiles = [ secretsEnv ];
        dependsOn = [ "defectdojo-postgres" "defectdojo-valkey" ];
        extraOptions = net;
      };
      defectdojo-nginx = {
        image = ddNginxImage;
        environment = { NGINX_METRICS_ENABLED = "false"; DD_UWSGI_HOST = "defectdojo-uwsgi"; DD_UWSGI_PORT = "3031"; };
        ports = [ "127.0.0.1:8080:8080" ];
        volumes = [ "defectdojo_media:/usr/share/nginx/html/media" ];
        dependsOn = [ "defectdojo-uwsgi" ];
        extraOptions = net;
      };
    };

    # Initializer = one-shot (migrations + admin), avant django/celery.
    systemd.services.defectdojo-initializer = {
      description = "DefectDojo initializer (migrations + admin, one-shot)";
      after = [ "docker.service" "init-defectdojo-network.service" "docker-defectdojo-postgres.service" ];
      requires = [ "init-defectdojo-network.service" "docker-defectdojo-postgres.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot"; RemainAfterExit = true;
        # SÉCURITÉ : ne JAMAIS bloquer le switch indéfiniment (leçon apprise).
        TimeoutStartSec = "600";
        ExecStartPre = "-${pkgs.docker}/bin/docker rm -f defectdojo-initializer";
        ExecStart = ''
          ${pkgs.docker}/bin/docker run --rm --name defectdojo-initializer --network=${ddNet} \
            --env-file ${secretsEnv} \
            -e DD_INITIALIZE=true -e DD_ADMIN_USER=admin -e DD_ADMIN_MAIL=admin@defectdojo.local \
            -e DD_ADMIN_FIRST_NAME=Admin -e DD_ADMIN_LAST_NAME=User -e DD_DATABASE_READINESS_TIMEOUT=30 \
            ${ddDjangoImage} /wait-for-it.sh defectdojo-postgres:5432 -- /entrypoint-initializer.sh
        '';
      };
    };
    systemd.services.docker-defectdojo-uwsgi = { after = [ "defectdojo-initializer.service" ]; requires = [ "defectdojo-initializer.service" ]; };
    systemd.services.docker-defectdojo-celeryworker = { after = [ "defectdojo-initializer.service" ]; requires = [ "defectdojo-initializer.service" ]; };
    systemd.services.docker-defectdojo-celerybeat = { after = [ "defectdojo-initializer.service" ]; requires = [ "defectdojo-initializer.service" ]; };

    environment.systemPackages = [ ddMcp setup ddImport ];
  };
}
