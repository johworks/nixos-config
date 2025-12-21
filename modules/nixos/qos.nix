{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.qos;
  concatPorts = ports: lib.concatStringsSep " " (map toString ports);
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

    gamingUdpPorts = mkOption {
      type = types.listOf types.int;
      default = [ 3074 3478 3479 3480 3481 ];
      description = "Gaming/interactive UDP ports to mark high priority.";
    };

    voipUdpPorts = mkOption {
      type = types.listOf types.int;
      default = [ 5060 5061 ];
      description = "VoIP UDP ports to mark EF.";
    };

    interactiveTcpPorts = mkOption {
      type = types.listOf types.int;
      default = [ 22 ];
      description = "Interactive TCP ports (e.g., SSH) to mark higher priority.";
    };

    bulkTcpPorts = mkOption {
      type = types.listOf types.int;
      default = [ 6881 6882 6883 6884 6885 6886 6887 6888 6889 ];
      description = "Bulk/background TCP ports to mark CS1.";
    };
  };

  config = mkIf cfg.enable {
    boot.kernelModules = [ "ifb" ];

    environment.systemPackages = [ pkgs.iproute2 ];

    networking.nftables = {
      enable = true;
      tables.qos = {
        family = "inet";
        content = ''
          table inet qos {
            chain prerouting {
              type filter hook prerouting priority mangle; policy accept;

              # Gaming / interactive UDP -> CS6 (voice-equivalent in diffserv4)
              udp dport { ${concatPorts cfg.gamingUdpPorts} } dscp set cs6 counter comment "gaming"

              # VoIP -> EF
              udp dport { ${concatPorts cfg.voipUdpPorts} } dscp set ef counter comment "voip"

              # SSH -> CS4 (video class in diffserv4)
              tcp dport { ${concatPorts cfg.interactiveTcpPorts} } dscp set cs4 counter comment "ssh"

              # Bulk -> CS1 (background)
              tcp dport { ${concatPorts cfg.bulkTcpPorts} } dscp set cs1 counter comment "bulk-tcp"
            }

            chain output {
              type filter hook output priority mangle; policy accept;

              tcp dport { ${concatPorts cfg.interactiveTcpPorts} } dscp set cs4 counter comment "ssh-local"
            }
          }
        '';
      };
    };

    systemd.services.qos-shaper = {
      description = "CAKE QoS shaper";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      requires = [ "network-online.target" ];
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
