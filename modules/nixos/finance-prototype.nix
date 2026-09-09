{ config, lib, pkgs, ... }:

let
  cfg = config.services.financePrototype;

  financePrototype = pkgs.writeShellApplication {
    name = "finance-prototype";
    runtimeInputs = [ pkgs.nodejs_22 ];
    text = ''
      export FINANCE_PUBLIC_DIR="${../../experiments/finance-prototype/public}"
      exec node ${../../experiments/finance-prototype/src/server.mjs}
    '';
  };

  envFileArgs = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
  sopsEnvFile =
    if cfg.useSops then
      config.sops.secrets."finance-prototype.env".path
    else
      null;
  environmentFiles =
    envFileArgs ++ lib.optional (sopsEnvFile != null) sopsEnvFile;
in
{
  options.services.financePrototype = {
    enable = lib.mkEnableOption "local finance prototype";

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address the finance prototype HTTP server binds to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8077;
      description = "Port for the finance prototype HTTP server.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/finance-prototype";
      description = "Directory where imported finance data is stored.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional plaintext dotenv file with Teller credentials and access tokens.";
    };

    useSops = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use sops-nix to provide the finance prototype dotenv file.";
    };

    sopsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Sops-encrypted dotenv file with Teller credentials and access tokens.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the configured port in the NixOS firewall.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(cfg.useSops && cfg.environmentFile != null);
        message = "services.financePrototype: use either useSops or environmentFile, not both.";
      }
      {
        assertion = cfg.useSops -> cfg.sopsFile != null;
        message = "services.financePrototype.useSops requires services.financePrototype.sopsFile.";
      }
    ];

    sops.secrets."finance-prototype.env" = lib.mkIf cfg.useSops {
      sopsFile = cfg.sopsFile;
      format = "dotenv";
      owner = "finance-prototype";
      group = "finance-prototype";
      mode = "0400";
      restartUnits = [ "finance-prototype.service" ];
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 finance-prototype finance-prototype - -"
    ];

    users.users.finance-prototype = {
      isSystemUser = true;
      group = "finance-prototype";
      home = cfg.dataDir;
    };

    users.groups.finance-prototype = { };

    systemd.services.finance-prototype = {
      description = "Local finance prototype";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "simple";
        User = "finance-prototype";
        Group = "finance-prototype";
        WorkingDirectory = cfg.dataDir;
        EnvironmentFile = environmentFiles;
        Environment = [
          "FINANCE_ADDR=${cfg.bindAddress}:${toString cfg.port}"
          "FINANCE_DATA_DIR=${cfg.dataDir}"
        ];
        ExecStart = "${financePrototype}/bin/finance-prototype";
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
