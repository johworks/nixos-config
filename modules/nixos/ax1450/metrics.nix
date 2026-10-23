{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.services.ax1450;
  directory = "/var/lib/ax1450-metrics";
  knownHosts = pkgs.writeText "ax1450-metrics-known-hosts" (
    "[${cfg.ap}]:${toString cfg.sshPort} ${builtins.readFile ./pinned-host-key.pub}"
  );
  collect = pkgs.writeShellApplication {
    name = "ax1450-metrics";
    runtimeInputs = [
      pkgs.openssh
      pkgs.python3
    ];
    text = ''
      exec python3 ${./metrics.py} \
        --host ${lib.escapeShellArg cfg.ap} \
        --port ${toString cfg.sshPort} \
        --key ${lib.escapeShellArg config.sops.secrets.ax1450_ssh_key.path} \
        --known-hosts ${knownHosts} \
        --remote-script ${./collect-remote.sh} \
        --output ${directory}/ax1450.prom "$@"
    '';
  };
in
{
  options.services.ax1450.metrics.enable =
    lib.mkEnableOption "read-only AX1450 metrics through node exporter's textfile collector";

  config = lib.mkIf (cfg.enable && cfg.metrics.enable) {
    system.build.ax1450-metrics = collect;
    services.prometheus.exporters.node = {
      enabledCollectors = [ "textfile" ];
      extraFlags = [ "--collector.textfile.directory=${directory}" ];
    };
    sops.secrets.ax1450_ssh_key.restartUnits = [ "ax1450-metrics.service" ];
    systemd.services.ax1450-metrics = {
      description = "Collect read-only AX1450 Wi-Fi metrics";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "25s";
        StateDirectory = "ax1450-metrics";
        StateDirectoryMode = "0755";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        UMask = "0077";
      };
      script = "${collect}/bin/ax1450-metrics";
    };
    systemd.timers.ax1450-metrics = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "30s";
        AccuracySec = "1s";
        Unit = "ax1450-metrics.service";
      };
    };
  };
}
