{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.qos;
in {
  options.qos = {
    enable = mkEnableOption "CAKE-based QoS";

    wanInterface = mkOption {
      type = types.str;
      default = "eth0";
      description = "WAN interface to shape (ingress/egress).";
    };

    downloadMbit = mkOption {
      type = types.int;
      default = 900;
      description = "Shaped downstream rate (Mbit/s), set to ~90–95% of line rate.";
    };

    uploadMbit = mkOption {
      type = types.int;
      default = 40;
      description = "Shaped upstream rate (Mbit/s), set to ~90–95% of line rate.";
    };
  };

  config = mkIf cfg.enable {
    boot.kernelModules = [ "ifb" ];

    systemd.services.qos-shaper = {
      description = "CAKE QoS shaper";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      requires = [ "network-online.target" ];
      path = [ pkgs.iproute2 ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 5;
      };
      script = ''
        set -euo pipefail

        WAN=${cfg.wanInterface}
        IFB="ifb0"
        DOWN="${toString cfg.downloadMbit}mbit"
        UP="${toString cfg.uploadMbit}mbit"

        # Clear any existing qdiscs
        tc qdisc del dev "$WAN" root 2>/dev/null || true
        tc qdisc del dev "$WAN" ingress 2>/dev/null || true
        ip link set "$IFB" down 2>/dev/null || true
        tc qdisc del dev "$IFB" root 2>/dev/null || true
        ip link delete "$IFB" 2>/dev/null || true

        ip link add "$IFB" type ifb
        ip link set "$IFB" up

        # Egress shaping (upload)
        tc qdisc add dev "$WAN" root cake bandwidth "$UP" diffserv4 nat dual-srchost nowash

        # Ingress shaping (download) via IFB redirect
        tc qdisc add dev "$WAN" handle ffff: ingress
        tc filter add dev "$WAN" parent ffff: protocol all u32 match u32 0 0 action mirred egress redirect dev "$IFB"
        tc qdisc add dev "$IFB" root cake bandwidth "$DOWN" diffserv4 nat dual-dsthost ingress
      '';
    };
  };
}
