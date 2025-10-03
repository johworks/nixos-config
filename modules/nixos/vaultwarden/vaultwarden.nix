{ config, lib, pkgs, ... }:

let
  myDomain = "vault.goobhub.org";
  myAcmeEmail = "viridianveil@protonmail.com";
  backupDir = "/data/vaultwarden/backups";
in
{
  #####################################################################
  # 1. Vaultwarden service
  #####################################################################

  systemd.tmpfiles.rules = [
    "d ${backupDir} 0750 vaultwarden vaultwarden -"
    # Cache dir for restic
    "d /var/cache/restic 0700 root root -"
    "d /var/lib/vw-stage 0700 root root -"
  ];

  services.vaultwarden = {
    enable    = true;
    dbBackend = "sqlite";
    backupDir = "${backupDir}";
    config = {
      # Only listen on localhost; nginx will terminate TLS
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT    = 8222;

      # Tell users the external URL is HTTPS
      DOMAIN = "https://${myDomain}";

      SIGNUPS_ALLOWED = true;
      ADMIN_TOKEN = "$argon2id$v=19$m=65540,t=3,p=4$aRPjxTgv5LL3fD9Tv4cV+ksx1odV6IN7TA/leVyBQNQ$fHUzPUj6Vwgg6wToZSQLdm5GEp86G1eENPtr0wBFcSU";
    };
  };

  #####################################################################
  # 2. Nginx reverse‑proxy with ACME
  #####################################################################
  services.nginx = {
    enable = true;
    virtualHosts."${myDomain}" = {
      forceSSL   = true;
      enableACME = true;

      # 1) Admin only on localhost
      locations."/admin" = {
        # only allow 127.0.0.1 (and maybe your LAN) to hit /admin
        proxyPass       = "http://127.0.0.1:8222";
        proxyWebsockets = true;
        extraConfig = ''
          allow 127.0.0.1;
          deny all;
        '';
      };

      locations."/" = {
        proxyPass       = "http://127.0.0.1:8222";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host              $host;
          proxy_set_header X-Real-IP         $remote_addr;
          proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };


  #####################################################################
  # 3. ACME global settings
  #####################################################################
  security.acme = {
    acceptTerms = true;
    # globally used for any host with enableACME = true
    defaults = {
      email  = "${myAcmeEmail}";
      # Use the staging server for testing?
      # caServer = "https://acme-staging-v02.api.letsencrypt.org/directory";
    };
    # ensure the nginx challenge makes it through
    #webroot = "/var/lib/acme/acme-challenges";
  };

  #####################################################################
  # 4. Firewall
  #####################################################################
  networking.firewall = {
    allowedTCPPorts = [ 80 443 ];
    # ensure nginx can bind
    enable = true;
  };

  #####################################################################
  # 5. CLI helpers (generate admin_token hash)
  #####################################################################
  environment.systemPackages = with pkgs; [ vaultwarden restic sqlite coreutils ];

  #####################################################################
  # 6. Backup to the cloud (AWS + restic)
  #####################################################################

  # Encrypted secrets file
  sops.secrets."s3.env" = {
    sopsFile = ./secrets/s3.env;
    format = "dotenv";
    owner  = "root";
    group  = "root";
    mode   = "0400";
  };


  systemd.services."vw-backup-to-s3" = {
    description = "Vaultwarden: local backup then encrypted upload (restic -> s3)";
    after = [ "backup-vaultwarden.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    #unitConfig.ConditionPathExists=!"/run/systemd/system/backup-vaultwarden.service.d"; # harmless; we'll also check in the script
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.secrets."s3.env".path;
      Environment = [
        "RESTIC_CACHE_DIR=/var/cache/restic"
        "HOME=/root"
        "STAGE_ROOT=/var/lib/vw-stage"
      ];
      # Keep temp files private during run:
      PrivateTmp = true;
    };
    path = with pkgs; [ bash coreutils sqlite restic systemd ];
    script = ''
      set -Eeuo pipefail

      # Ensure repo exists
      restic snapshots >/dev/null 2>&1 || restic init
      stamp="$(date -u +%Y%m%dT%H%M%SZ)"

      # Default: try to use the built-in VW snapshot in-place
      src="${backupDir}"
      use_fallback=0

      # If the unit exists, run it to refresh the in-place snapshot
      if systemctl --quiet is-enabled backup-vaultwarden.service 2>/dev/null; then
        systemctl start backup-vaultwarden.service || true
      fi

      # If the in-place snapshot folder doesn't have a DB yet, fall back to staging
      if [ ! -e "${backupDir}/db.sqlite3" ]; then
        echo "No db.sqlite3 in ${backupDir}; using fallback staging." >&2
        use_fallback=1
      fi

      if [ "$use_fallback" -eq 1 ]; then
        # Stage a minimal snapshot OUTSIDE backupDir (keeps it clean)
        data_dir=/var/lib/vaultwarden
        stage="$(mktemp -d "''${STAGE_ROOT:-/var/lib/vw-stage}/stage-$stamp-XXXX")"
        trap 'rm -rf "$stage"' EXIT

        sqlite3 "$data_dir/db.sqlite3" ".backup '$stage/db.sqlite3'"
        [ -d "$data_dir/attachments" ] && cp -a "$data_dir/attachments" "$stage/attachments"
        [ -d "$data_dir/sends" ]       && cp -a "$data_dir/sends"       "$stage/sends"
        [ -f "$data_dir/rsa_key.pem" ] && cp    "$data_dir/rsa_key.pem" "$stage/rsa_key.pem"

        src="$stage"
      fi


      # Build a list of only the items we care about
      paths=()
      [ -f "$src/db.sqlite3" ]      && paths+=("$src/db.sqlite3")
      [ -d "$src/attachments" ]     && paths+=("$src/attachments")
      [ -d "$src/sends" ]           && paths+=("$src/sends")
      [ -f "$src/rsa_key.pem" ]     && paths+=("$src/rsa_key.pem")

      if [ "''${#paths[@]}" -eq 0 ]; then
        echo "Nothing to back up under $src (no db/attachments/sends/rsa_key found)" >&2
        exit 0
      fi

      # Now back up exactly those paths (no icon_cache/tmp anymore)
      restic backup "''${paths[@]}" \
        --tag vaultwarden \
        --host "${config.networking.hostName}" \
        --compression auto

      # Retention
      restic unlock || true
      restic forget --retry-lock 2m \
        --keep-daily 14 --keep-weekly 8 --keep-monthly 12 --prune
    '';
  };

  systemd.timers."vw-backup-to-s3" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";        # or "03:40", "Mon..Fri 03:40", etc.
      RandomizedDelaySec = "1h";
      Persistent = true;           # catch up after downtime
      Unit = "vw-backup-to-s3.service";  # optional, but explicit
    };
  };



}
