{ config, lib, pkgs, ... }:

let
  cfg = config.services.homeAssistantAnalysis;

  app = pkgs.writeShellApplication {
    name = "home-assistant-analysis";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${./home-assistant-analysis/app.py} "$@"
    '';
  };
in
{
  options.services.homeAssistantAnalysis = {
    enable = lib.mkEnableOption "Home Assistant AC analysis";

    baseUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8123";
      description = "Home Assistant base URL used by the ingest job.";
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      default = config.sops.secrets."home-assistant-mcp.env".path;
      description = "Dotenv file containing HA_MCP_TOKEN or API_ACCESS_TOKEN.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/home-assistant-analysis";
      description = "Directory where the analysis SQLite database is stored.";
    };

    bucketMinutes = lib.mkOption {
      type = lib.types.int;
      default = 15;
      description = "Bucket size for AC analysis rows.";
    };

    lookbackHours = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "History lookback used on each ingest run to update recent buckets.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "15min";
      description = "Systemd timer interval for analysis ingestion.";
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Address the analysis dashboard binds to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8091;
      description = "Port for the analysis dashboard.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open the dashboard port in the firewall.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 john users - -"
    ];

    systemd.services.home-assistant-analysis-ingest = {
      description = "Ingest Home Assistant AC analysis data";
      after = [ "network-online.target" "podman-home-assistant.service" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "john";
        Group = "users";
        WorkingDirectory = cfg.dataDir;
        Environment = [
          "HA_BASE_URL=${cfg.baseUrl}"
          "HA_TOKEN_FILE=${cfg.tokenFile}"
          "AC_ANALYSIS_DB=${cfg.dataDir}/ac-analysis.sqlite3"
          "AC_ANALYSIS_BUCKET_MINUTES=${toString cfg.bucketMinutes}"
          "AC_ANALYSIS_LOOKBACK_HOURS=${toString cfg.lookbackHours}"
        ];
        ExecStart = "${app}/bin/home-assistant-analysis --db ${cfg.dataDir}/ac-analysis.sqlite3 ingest";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadOnlyPaths = [ cfg.tokenFile ];
        ReadWritePaths = [ cfg.dataDir ];
      };
    };

    systemd.timers.home-assistant-analysis-ingest = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = cfg.interval;
        Persistent = true;
        Unit = "home-assistant-analysis-ingest.service";
      };
    };

    systemd.services.home-assistant-analysis = {
      description = "Home Assistant AC analysis dashboard";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "home-assistant-analysis-ingest.service" ];
      wants = [ "network-online.target" "home-assistant-analysis-ingest.service" ];
      serviceConfig = {
        Type = "simple";
        User = "john";
        Group = "users";
        WorkingDirectory = cfg.dataDir;
        Environment = [
          "AC_ANALYSIS_DB=${cfg.dataDir}/ac-analysis.sqlite3"
          "AC_ANALYSIS_HOST=${cfg.bindAddress}"
          "AC_ANALYSIS_PORT=${toString cfg.port}"
        ];
        ExecStart = "${app}/bin/home-assistant-analysis --db ${cfg.dataDir}/ac-analysis.sqlite3 serve";
        Restart = "on-failure";
        RestartSec = "5s";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.dataDir ];
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
