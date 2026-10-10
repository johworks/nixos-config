{
  config,
  inputs,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  # Use one locked package source even on the NUC's stable NixOS release.
  beads = inputs.nixpkgsUnstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.beads;
  port = if config.beads.localServer then "3307" else "13307";
  client = pkgs.writeShellApplication {
    name = "bd";
    text = ''
      export BEADS_DOLT_SERVER_MODE=1
      export BEADS_DOLT_SERVER_HOST=127.0.0.1
      export BEADS_DOLT_SERVER_PORT=${port}
      export BEADS_DOLT_AUTO_START=0
      export BEADS_ACTOR="''${BEADS_ACTOR:-${osConfig.networking.hostName}:''${CODEX_THREAD_ID:-$USER}}"
      exec ${beads}/bin/bd "$@"
    '';
  };
in
{
  options.beads.localServer = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Connect directly to the local Dolt service instead of tunneling to the NUC.";
  };

  config = {
    home.packages = [ client ];

    systemd.user.services.beads-tunnel = lib.mkIf (!config.beads.localServer) {
      Unit = {
        Description = "SSH tunnel to the NUC Beads database";
        StartLimitIntervalSec = 0;
      };
      Service = {
        # Hosts need the existing NUC SSH key before they can connect.
        ExecCondition = "${pkgs.coreutils}/bin/test -r ${config.home.homeDirectory}/.ssh/id_ed25519_nuc";
        ExecStart = "${pkgs.openssh}/bin/ssh -NT -o BatchMode=yes -o IdentitiesOnly=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -i ${config.home.homeDirectory}/.ssh/id_ed25519_nuc -L 127.0.0.1:13307:127.0.0.1:3307 john@192.168.10.1";
        Restart = "always";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
