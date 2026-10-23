{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:
let
  cfg = config.services.signalUpdates;
  helper = pkgs.writeShellApplication {
    name = "signal-updates";
    runtimeInputs = [ pkgs.qrencode ];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./client.py} "$@"
    '';
  };
in
{
  options.services.signalUpdates.enable = lib.mkEnableOption "the private Signal update notification transport";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ helper ];

    users.groups.signal-updates = { };
    users.users.signal-updates = {
      isSystemUser = true;
      group = "signal-updates";
      home = "/var/lib/signal-updates";
    };

    # No TCP listener, agent access, or activation privileges. Personal account
    # keys belong to this service and are created only when John scans the QR.
    systemd.services.signal-updates = {
      description = "Private Signal update notification transport";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      environment.HOME = "/var/lib/signal-updates";
      serviceConfig = {
        User = "signal-updates";
        Group = "signal-updates";
        StateDirectory = "signal-updates";
        StateDirectoryMode = "0700";
        RuntimeDirectory = "signal-updates";
        RuntimeDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/signal-updates";
        # Follow the unstable input: Signal protocol changes require fresh clients.
        ExecStart = "${pkgsUnstable.signal-cli}/bin/signal-cli --config /var/lib/signal-updates --scrub-log daemon --socket /run/signal-updates/rpc.sock --no-receive-stdout --ignore-attachments --ignore-stories --ignore-avatars --ignore-stickers";
        StandardOutput = "null";
        Restart = "on-failure";
        RestartSec = 15;
        UMask = "0077";
        NoNewPrivileges = true;
        CapabilityBoundingSet = "";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
      };
    };
  };
}
