{
  config,
  lib,
  pkgsUnstable,
  ...
}:
let
  beads = pkgsUnstable.beads;
  dolt = pkgsUnstable.dolt;
in
{
  options.services.beadsDolt.enable = lib.mkEnableOption "the shared Beads Dolt server";

  config = lib.mkIf config.services.beadsDolt.enable {
    users.groups.beads-dolt = { };
    users.users.beads-dolt = {
      isSystemUser = true;
      group = "beads-dolt";
      home = "/var/lib/beads-dolt";
    };

    # Clients authenticate through SSH; the SQL listener stays on loopback.
    systemd.services.beads-dolt = {
      description = "Shared Beads Dolt database";
      wantedBy = [ "multi-user.target" ];
      environment = {
        HOME = "/var/lib/beads-dolt";
        BEADS_DIR = "/var/lib/beads-dolt-client";
        BEADS_DOLT_SERVER_MODE = "1";
        BEADS_DOLT_SERVER_HOST = "127.0.0.1";
        BEADS_DOLT_SERVER_PORT = "3307";
        BEADS_DOLT_AUTO_START = "0";
        BEADS_ACTOR = "beads-dolt-bootstrap";
      };
      preStart = ''
        ${dolt}/bin/dolt config --global --add user.name "Beads NUC"
        ${dolt}/bin/dolt config --global --add user.email "beads@localhost"
      '';
      postStart = ''
        install -m 600 ${../../.beads/metadata.json} "$BEADS_DIR/metadata.json"
        install -m 600 ${../../.beads/config.yaml} "$BEADS_DIR/config.yaml"

        until ${dolt}/bin/dolt --host 127.0.0.1 --port 3307 --user root \
          --password "" --no-tls sql --query "SELECT 1" >/dev/null 2>&1; do
          sleep 1
        done

        # Initialize only an absent database; an existing database is never reset.
        if [ ! -d /var/lib/beads-dolt/nixos_config ]; then
          ${beads}/bin/bd init --server --external --database nixos_config \
            --prefix nixos --server-port 3307 --stealth --skip-hooks \
            --skip-agents --non-interactive
        fi
        ${beads}/bin/bd list --json >/dev/null
      '';
      serviceConfig = {
        User = "beads-dolt";
        Group = "beads-dolt";
        StateDirectory = [
          "beads-dolt"
          "beads-dolt-client"
          "beads-dolt-backup"
        ];
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/beads-dolt";
        ExecStart = "${dolt}/bin/dolt sql-server --host 127.0.0.1 --port 3307 --data-dir /var/lib/beads-dolt";
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStartSec = 60;
        UMask = "0077";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };

    # Dolt backups include history and uncommitted work without stopping the server.
    systemd.services.beads-dolt-backup = {
      description = "Back up the nixos-config Beads database";
      requires = [ "beads-dolt.service" ];
      after = [ "beads-dolt.service" ];
      environment.HOME = "/var/lib/beads-dolt";
      serviceConfig = {
        Type = "oneshot";
        User = "beads-dolt";
        Group = "beads-dolt";
        WorkingDirectory = "/var/lib/beads-dolt";
        ExecStart = "${dolt}/bin/dolt --host 127.0.0.1 --port 3307 --user root --password \"\" --no-tls --use-db nixos_config sql --query \"CALL DOLT_BACKUP('sync-url', 'file:///var/lib/beads-dolt-backup/nixos_config');\"";
        UMask = "0077";
      };
    };

    systemd.timers.beads-dolt-backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };
}
