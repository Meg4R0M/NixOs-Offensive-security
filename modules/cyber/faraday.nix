# ─────────────────────────────────────────────────────────────────────────────
# Humanix · Faraday — dashboard bug bounty (historique + visuel des findings)
# ─────────────────────────────────────────────────────────────────────────────
# Plateforme FaradaySec (pas dans nixpkgs) lancée via virtualisation.oci-containers
# (backend docker, déjà présent). 2 conteneurs : postgres + faraday. UI web sur
# 127.0.0.1:5985. `faraday-cli` (natif nixpkgs) pour importer les scans (nuclei
# JSON, nmap XML) après un run HexStrike.
#
# Les outils offensifs restent 100% NATIFS ; seul CE service de dashboard est
# conteneurisé. Mots de passe DB + admin générés à l'activation (fichier root,
# hors store, SANS rapport avec le login → aucun risque de lockout).
# Débrayable : humanix.ai.faraday.enable (défaut OFF).
{ lib, pkgs, config, ... }:
let
  cfg = config.humanix.ai.faraday;
  inherit (lib) mkEnableOption mkOption types mkIf mkDefault;

  dataDir    = "/var/lib/faraday";
  pgData     = "${dataDir}/pgdata";
  appData    = "${dataDir}/appdata";
  secretsDir = "${dataDir}/secrets";
  net        = "faraday-net";
  pgImage    = "docker.io/library/postgres:16-alpine";
  faradayImg = "docker.io/faradaysec/faraday:${cfg.tag}";

  info = pkgs.writeShellScriptBin "faraday-info" ''
    echo "Faraday  ▸ http://127.0.0.1:5985"
    echo "user     ▸ faraday"
    if [ -r ${secretsDir}/app.env ]; then
      echo -n "password ▸ "; ${pkgs.gnugrep}/bin/grep FARADAY_PASSWORD ${secretsDir}/app.env | cut -d= -f2
    else
      echo "password ▸ (lance avec sudo : sudo faraday-info)"
    fi
    echo
    echo "Import d'un scan :  faraday-cli auth  &&  faraday-cli tool report ./nuclei.json"
  '';
in {
  options.humanix.ai.faraday = {
    enable = mkEnableOption "Faraday — dashboard bug bounty (conteneur docker géré par NixOS)";
    tag = mkOption {
      type = types.str;
      default = "latest";
      description = "Tag de l'image faradaysec/faraday (épingle une version stable en prod).";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.docker.enable = mkDefault true;
    virtualisation.oci-containers.backend = "docker";

    # Prépare dossiers + réseau + secrets (générés une fois) avant les conteneurs.
    systemd.services.faraday-init = {
      description = "Faraday : dossiers, réseau docker, secrets";
      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      before = [ "docker-faraday-db.service" "docker-faraday.service" ];
      path = [ pkgs.docker pkgs.openssl pkgs.coreutils pkgs.gnugrep ];
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      script = ''
        install -d -m 0700 ${pgData} ${appData} ${secretsDir}
        docker network inspect ${net} >/dev/null 2>&1 || docker network create ${net}
        if [ ! -f ${secretsDir}/db.env ]; then
          PW=$(openssl rand -hex 24)
          ADM=$(openssl rand -hex 16)
          umask 077
          printf 'POSTGRES_USER=faraday\nPOSTGRES_PASSWORD=%s\nPOSTGRES_DB=faraday\n' "$PW" > ${secretsDir}/db.env
          printf 'PGSQL_USER=faraday\nPGSQL_PASSWD=%s\nFARADAY_PASSWORD=%s\n' "$PW" "$ADM" > ${secretsDir}/app.env
          chmod 600 ${secretsDir}/db.env ${secretsDir}/app.env
        fi
      '';
    };

    virtualisation.oci-containers.containers = {
      faraday-db = {
        image = pgImage;
        environmentFiles = [ "${secretsDir}/db.env" ];
        volumes = [ "${pgData}:/var/lib/postgresql/data" ];
        extraOptions = [
          "--network=${net}"
          "--health-cmd=pg_isready -U faraday"
          "--health-interval=5s"
          "--health-retries=10"
        ];
      };
      faraday = {
        image = faradayImg;
        dependsOn = [ "faraday-db" ];
        ports = [ "127.0.0.1:5985:5985" ];
        environment = {
          PGSQL_HOST = "faraday-db";
          PGSQL_DBNAME = "faraday";
        };
        environmentFiles = [ "${secretsDir}/app.env" ];
        volumes = [ "${appData}:/home/faraday/.faraday" ];
        extraOptions = [ "--network=${net}" ];
      };
    };

    # Client d'import natif + helper d'info.
    environment.systemPackages = [ pkgs.faraday-cli info ];
  };
}
