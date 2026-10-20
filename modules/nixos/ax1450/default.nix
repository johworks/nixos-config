{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.services.ax1450;

  # Public half of the Dropbear host key pinned inside the AP's bootstrap
  # payload. Regenerating the payload (experiments/ax1450/make-bootstrap.py)
  # requires updating this file and expectedBootstrapSha256.
  hostKeyLine = builtins.readFile ./pinned-host-key.pub;

  knownHosts = pkgs.writeText "ax1450-known-hosts" (
    "[${cfg.ap}]:${toString cfg.sshPort} ${hostKeyLine}"
  );

  remoteScript = pkgs.writeText "ax1450-reconcile-remote" (builtins.readFile ./reconcile-remote.sh);

  # The persisted autoreboot day value on the AP: a short loader that
  # materializes /etc/ax1450/bootstrap.sh from the router-config flash
  # partition and runs it. The '#' comments out the vendor reboot command.
  dayValue = "* mkdir -p /etc/ax1450; /usr/bin/nvrammanager -r /etc/ax1450/payload.b64 -p router-config; /usr/bin/openssl base64 -d -A -in /etc/ax1450/payload.b64 | tee /etc/ax1450/bootstrap.sh | /bin/sh #";

  sshKeyPath = config.sops.secrets."ax1450_ssh_key".path;
  pskPath = config.sops.secrets."ax1450_wifi_psk".path;

  reconcile = pkgs.writeShellApplication {
    name = "ax1450-reconcile";
    runtimeInputs = [ pkgs.openssh ];
    text = ''
      set -euo pipefail

      psk_b64=$(base64 -w0 "${pskPath}")
      ssid=${lib.escapeShellArg cfg.wifi.ssid}
      day_value=${lib.escapeShellArg dayValue}
      expected_sha=${lib.escapeShellArg cfg.expectedBootstrapSha256}

      remote_cmd=$(printf '/bin/sh -s -- %q %q %q %q %q %q' \
        "$psk_b64" "$ssid" "$day_value" "$expected_sha" \
        "${toString cfg.sshPort}" "${cfg.managerIp}")

      if ! ssh -F /dev/null \
        -i "${sshKeyPath}" \
        -o IdentitiesOnly=yes \
        -o UserKnownHostsFile="${knownHosts}" \
        -o StrictHostKeyChecking=yes \
        -o HostKeyAlgorithms=+ssh-rsa \
        -o PubkeyAcceptedAlgorithms=+ssh-rsa \
        -o ConnectTimeout=15 \
        -p "${toString cfg.sshPort}" \
        "root@${cfg.ap}" "$remote_cmd" < "${remoteScript}"; then
        echo "AX1450 reconcile failed. If the AP rebooted recently, root SSH returns at the next 03:11 scheduler fire." >&2
        exit 1
      fi
    '';
  };
in
{
  options.services.ax1450 = {
    enable = lib.mkEnableOption "Archer AX1450 AP management from this host";

    ap = lib.mkOption {
      type = lib.types.str;
      default = "192.168.10.161";
      description = "Management address of the AP.";
    };

    sshPort = lib.mkOption {
      type = lib.types.port;
      default = 2222;
      description = "Port of the AP's key-only root Dropbear listener.";
    };

    managerIp = lib.mkOption {
      type = lib.types.str;
      default = "192.168.10.1";
      description = "This host's LAN address, allowed by the AP's SSH firewall rules.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "10min";
      description = "Interval between reconcile runs.";
    };

    expectedBootstrapSha256 = lib.mkOption {
      type = lib.types.str;
      default = "85ebac42b0ec3da54c9d2079fd1bac99578ab798425479f41a01889d454d0e62";
      description = "sha256 of the bootstrap script stored in the AP's router-config partition.";
    };

    wifi = {
      ssid = lib.mkOption {
        type = lib.types.str;
        description = "Desired SSID of the main network (both bands, smart-connect).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.wifi.ssid != "";
        message = "services.ax1450.wifi.ssid must be set.";
      }
    ];

    sops.secrets."ax1450_ssh_key" = {
      restartUnits = [ "ax1450-reconcile.service" ];
    };
    sops.secrets."ax1450_wifi_psk" = {
      restartUnits = [ "ax1450-reconcile.service" ];
    };

    systemd.services.ax1450-reconcile = {
      description = "Verify AX1450 root persistence and converge Wi-Fi settings";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        # Root to read the sops secrets (0400); the script only opens the
        # SSH connection and reads store paths.
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
      script = "${reconcile}/bin/ax1450-reconcile";
    };

    systemd.timers.ax1450-reconcile = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = cfg.interval;
        Unit = "ax1450-reconcile.service";
      };
    };
  };
}
