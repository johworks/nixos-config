{ config, pkgs, lib, ... }:

let
  cfg = config.services.ddns.cloudflare;

  # Python runtime + deps your script needs
  python = pkgs.python311.withPackages (ps: with ps; [
    requests
    #os         # always available
    cloudflare
  ]);

  # Store your script in the Nix store (from your repo file)
  ddnsScript = pkgs.writeText "update_cf_ddns.py"
    (builtins.readFile ./update_cf_ddns.py);

  # Simple wrapper to run the script with our Python
  ddnsRunner = pkgs.writeShellApplication {
    name = "cf-ddns";
    runtimeInputs = [ python ];
    text = ''
      exec ${python}/bin/python ${ddnsScript}
    '';
  };

  recordsForScript = map (record: {
    label = if record.name == null then record.recordName else record.name;
    zone_name = record.zoneName;
    record_name = record.recordName;
  }) cfg.records;

  recordsFile = pkgs.writeText "ddns-records.json"
    (builtins.toJSON recordsForScript);

  envFilePath =
    if cfg.useSops then
      config.sops.secrets."ddns.env".path
    else
      "/etc/ddns/ddns.env";
in
{
  options.services.ddns.cloudflare = {
    enable = lib.mkEnableOption "Cloudflare DDNS updater";

    records = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule ({ ... }: {
          options = {
            name = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Optional label for logs; defaults to recordName.";
            };
            zoneName = lib.mkOption {
              type = lib.types.str;
              description = "Cloudflare zone name (e.g. example.com).";
            };
            recordName = lib.mkOption {
              type = lib.types.str;
              description = "Record name to update (e.g. home.example.com).";
            };
          };
        })
      );
      default = [ ];
      description = "A records to keep in sync with the current public IP.";
    };

    useSops = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use sops-nix to provide the Cloudflare API token.";
    };

    sopsFile = lib.mkOption {
      type = lib.types.path;
      default = ./secrets/cloudflare.env;
      description = "Sops file with CF_API_TOKEN in dotenv format.";
    };

    onBootSec = lib.mkOption {
      type = lib.types.str;
      default = "2min";
      description = "Initial timer delay after boot.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "10min";
      description = "Timer interval between updates.";
    };

    randomizedDelaySec = lib.mkOption {
      type = lib.types.str;
      default = "30s";
      description = "Randomized delay to avoid synchronized runs.";
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.enable -> cfg.records != [ ];
          message = "services.ddns.cloudflare.enable is true but no records are configured.";
        }
      ];
    }

    (lib.mkIf (cfg.records != [ ]) {
      services.ddns.cloudflare.enable = lib.mkDefault true;
    })

    (lib.mkIf (cfg.enable && cfg.records != [ ]) {
      ############################################
      # (3a) sops-nix secret (dotenv format)
      ############################################
      sops.secrets."ddns.env" = lib.mkIf cfg.useSops {
        sopsFile = cfg.sopsFile; # your encrypted file
        format = "dotenv"; # KEY=value lines
        restartUnits = [ "ddns-cloudflare.service" ];
      };

      ############################################
      # (3b) Plaintext env file (alternative)
      ############################################
      # Only if not using sops. Replace values & set permissions appropriately.
      environment.etc."ddns/ddns.env" = lib.mkIf (!cfg.useSops) {
        text = ''
          CF_API_TOKEN=your_api_token_here
        '';
        mode = "0400";
        user = "root";
        group = "root";
      };

      ############################################
      # systemd service + timer
      ############################################
      systemd.services.ddns-cloudflare = {
        description = "Update Cloudflare A record for dynamic IP";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          DynamicUser = true; # no persistent user on disk
          EnvironmentFile = envFilePath; # dotenv from sops or plaintext
          Environment = [ "DDNS_RECORDS_PATH=${recordsFile}" ];
          # Hardening (tweak if your script reads files elsewhere)
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
          ReadWritePaths = [ "/tmp" ];
          # If you log to stdout/stderr, journal gets it.
          # If you want to write a cache, add a StateDirectory here.
        };
        # Make cf-ddns available on PATH for the script field
        path = [ ddnsRunner ];
        script = ''
          cf-ddns
        '';
      };

      systemd.timers.ddns-cloudflare = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = cfg.onBootSec;
          OnUnitActiveSec = cfg.interval; # run at the configured interval
          RandomizedDelaySec = cfg.randomizedDelaySec;
          Unit = "ddns-cloudflare.service";
        };
      };
    })
  ];
}
