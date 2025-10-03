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

      # Init repo on first run (no-op if it already exists)
      restic snapshots >/dev/null 2>&1 || restic init
      stamp="$(date -u +%Y%m%dT%H%M%SZ)"

      if systemctl --quiet is-enabled backup-vaultwarden.service 2>/dev/null; then
        systemctl start backup-vaultwarden.service
        # Use ONLY the newest VW-made snapshot dir under backupDir
        latest="$(ls -1dt ${backupDir}/*/ 2>/dev/null | head -n1 || true)"
        if [ -n "$latest" ]; then
          src="$latest"
        else
          src="${backupDir}"
        fi
      else
        # Fallback if your nixpkgs doesn’t ship the unit:
        data_dir=/var/lib/vaultwarden
        stage="$(mktemp -d "$STAGE_ROOT/stage-$stamp-XXXX")"
        trap 'rm -rf "$stage"' EXIT

        sqlite3 "$data_dir/db.sqlite3" ".backup '$stage/db.sqlite3'"
        [ -d "$data_dir/attachments" ] && cp -a "$data_dir/attachments" "$stage/attachments"
        [ -d "$data_dir/sends" ]       && cp -a "$data_dir/sends"       "$stage/sends"
        [ -f "$data_dir/rsa_key.pem" ] && cp    "$data_dir/rsa_key.pem" "$stage/rsa_key.pem"

        src="$stage"
      fi

      # 2) Encrypted offsite backup (restic->S3) (plus compressed)
        restic backup "$src" \
        --tag vaultwarden \
        --host "${config.networking.hostName}"\
        --compression auto \
        --exclude '**/icon_cache/**' \
        --exclude '**/tmp/**' \
        --exclude '**/*.miss'

      # 3) Apply retention and prune
      # Retention: wait a bit if the previous lock hasn't cleared yet
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
