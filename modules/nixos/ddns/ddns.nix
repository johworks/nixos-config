{ config, pkgs, lib, ... }:

let
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

  # Switch this to false if you’re not using sops-nix and prefer a plain env file (see §3b)
  usingSops = true;

  envFilePath = if usingSops then "/run/secrets/ddns.env" else "/etc/ddns/ddns.env";
in
{
  ############################################
  # (3a) sops-nix secret (dotenv format)
  ############################################
  # If you’re NOT using sops-nix, comment this block and use §3b instead.
  sops.secrets."ddns.env" = lib.mkIf usingSops {
    sopsFile = ./secrets/cloudflare.env;   # your encrypted file
    format = "dotenv";                     # KEY=value lines
    restartUnits = [ "ddns-cloudflare.service" ];
  };

  ############################################
  # (3b) Plaintext env file (alternative)
  ############################################
  # Only if not using sops. Replace values & set permissions appropriately.
  environment.etc."ddns/ddns.env" = lib.mkIf (!usingSops) {
    text = ''
      CF_API_TOKEN=your_api_token_here
      CF_ZONE_ID=your_zone_id_here
      CF_RECORD_NAME=home.example.com
      CF_RECORD_TTL=120
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
      DynamicUser = true;                  # no persistent user on disk
      EnvironmentFile = envFilePath;       # dotenv from sops or plaintext
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
      OnBootSec = "2min";
      OnUnitActiveSec = "10min";   # run every 10 minutes
      RandomizedDelaySec = "30s";
      Unit = "ddns-cloudflare.service";
    };
  };
}
