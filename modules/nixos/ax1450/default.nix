{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.services.ax1450;

  onOff = value: if value then "on" else "off";
  setting =
    section: option: value:
    lib.optionalString (value != null) "${section} ${option} ${toString value}\n";

  # Only these known vendor settings are accepted; no arbitrary UCI commands.
  radioSettings =
    section: radio:
    setting section "disabled_all" (if radio.enable == null then null else onOff (!radio.enable))
    + setting section "channel" radio.channel
    + setting section "htmode" radio.channelWidth
    + setting section "txpower" radio.transmitPower
    + setting section "isolate" (
      if radio.clientIsolation == null then null else onOff radio.clientIsolation
    );
  networkSettings =
    section:
    setting section "hidden" (if cfg.wifi.hidden == null then null else onOff cfg.wifi.hidden)
    + setting section "wps" (if cfg.wifi.wps == null then null else onOff cfg.wifi.wps);
  wifiSettings =
    radioSettings "wl1" cfg.wifi.radios."2g"
    + radioSettings "wl0" cfg.wifi.radios."5g"
    + networkSettings "wl13"
    + networkSettings "wl03"
    + setting "smart" "smart_enable" (
      if cfg.wifi.smartConnect == null then null else onOff cfg.wifi.smartConnect
    );

  radioOptions = channels: widths: {
    enable = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Software radio switch, including guest networks. Null leaves it unmanaged; the hardware switch is respected.";
    };
    channel = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ([ "auto" ] ++ channels));
      default = null;
      description = "Primary channel for this US AX1450, or auto. Null leaves it unmanaged.";
    };
    channelWidth = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ([ "auto" ] ++ widths));
      default = null;
      description = "Maximum channel width in MHz, or auto for vendor coexistence handling. Null leaves it unmanaged.";
    };
    transmitPower = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "low"
          "middle"
          "high"
        ]
      );
      default = null;
      description = "Vendor transmit-power preset within the existing regulatory limits. Null leaves it unmanaged.";
    };
    clientIsolation = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Isolate clients on this band's main BSS. This does not provide VLAN or whole-LAN isolation. Null leaves it unmanaged.";
    };
  };

  # Public half of the Dropbear host key pinned inside the AP's bootstrap
  # payload. Regenerating the payload (experiments/ax1450/make-bootstrap.py)
  # requires updating this file and expectedBootstrapSha256.
  hostKeyLine = builtins.readFile ./pinned-host-key.pub;

  knownHosts = pkgs.writeText "ax1450-known-hosts" (
    "[${cfg.ap}]:${toString cfg.sshPort} ${hostKeyLine}"
  );

  remoteScript = pkgs.writeText "ax1450-reconcile-remote" (
    ''
      SSID=${lib.escapeShellArg cfg.wifi.ssid}
      WIFI_SETTINGS=${lib.escapeShellArg wifiSettings}
      DAY_VALUE=${lib.escapeShellArg dayValue}
      EXPECTED_SHA=${lib.escapeShellArg cfg.expectedBootstrapSha256}
      PORT=${lib.escapeShellArg (toString cfg.sshPort)}
      MANAGER_IP=${lib.escapeShellArg cfg.managerIp}
    ''
    + builtins.readFile ./reconcile-remote.sh
  );

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

      # Base64 contains no shell metacharacters. Send the assignment and
      # script over stdin so neither SSH nor the remote shell exposes the
      # password in process arguments.
      if ! {
        printf 'PSK_B64=%s\n' "$psk_b64"
        cat "${remoteScript}"
      } | ssh -F /dev/null \
        -i "${sshKeyPath}" \
        -o BatchMode=yes \
        -o IdentitiesOnly=yes \
        -o UserKnownHostsFile="${knownHosts}" \
        -o StrictHostKeyChecking=yes \
        -o HostKeyAlgorithms=+ssh-rsa \
        -o PubkeyAcceptedAlgorithms=+ssh-rsa \
        -o ConnectTimeout=15 \
        -p "${toString cfg.sshPort}" \
        "root@${cfg.ap}" /bin/sh -s; then
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
      hidden = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Hide the main SSID on both bands. Null leaves it unmanaged.";
      };
      wps = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "WPS on both main networks. The firmware disables WPS for hidden SSIDs or incompatible security modes. Null leaves it unmanaged.";
      };
      smartConnect = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Vendor band steering; both bands still share the configured SSID and password. Null leaves it unmanaged.";
      };
      radios = {
        "2g" = radioOptions (lib.range 1 11) [
          "20"
          "40"
        ];
        "5g" =
          radioOptions
            [
              36
              40
              44
              48
              149
              153
              157
              161
              165
            ]
            [ "20" "40" "80" ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          cfg.wifi.ssid != ""
          && builtins.stringLength cfg.wifi.ssid <= 32
          && !(lib.hasInfix "\n" cfg.wifi.ssid)
          && !(lib.hasInfix "\r" cfg.wifi.ssid);
        message = "services.ax1450.wifi.ssid must contain 1–32 bytes without line breaks.";
      }
      {
        assertion =
          cfg.wifi.radios."5g".channel != 165
          || builtins.elem cfg.wifi.radios."5g".channelWidth [
            null
            "auto"
            "20"
          ];
        message = "AX1450 channel 165 supports only 20 MHz; use channelWidth = \"20\" or \"auto\".";
      }
    ];

    sops.secrets."ax1450_ssh_key" = {
      restartUnits = [ "ax1450-reconcile.service" ];
    };
    sops.secrets."ax1450_wifi_psk" = {
      restartUnits = [ "ax1450-reconcile.service" ];
    };

    system.build.ax1450-reconcile = reconcile;

    systemd.services.ax1450-reconcile = {
      description = "Verify AX1450 root persistence and converge Wi-Fi settings";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "3min";
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
