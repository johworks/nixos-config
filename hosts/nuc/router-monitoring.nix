{ pkgs, ... }:

{
  # The dashboard is a LAN appliance; all changes are provisioned from Git.
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "192.168.10.1";
        http_port = 3000;
        root_url = "http://192.168.10.1:3000/";
      };
      "auth.anonymous" = {
        enabled = true;
        org_name = "Main Org.";
        org_role = "Viewer";
      };
      auth = {
        disable_login_form = true;
        disable_signout_menu = true;
      };
      "auth.basic".enabled = false;
      security.disable_initial_admin_creation = true;
      users.allow_sign_up = false;
      analytics = {
        reporting_enabled = false;
        check_for_updates = false;
        check_for_plugin_updates = false;
      };
      dashboards.default_home_dashboard_path = "${./dashboards/home-network-health.json}";
    };
    provision = {
      enable = true;
      datasources.settings = {
        apiVersion = 1;
        prune = true;
        datasources = [
          {
            name = "Prometheus";
            uid = "prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:9090";
            isDefault = true;
            editable = false;
            jsonData.timeInterval = "15s";
          }
        ];
      };
      dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "home-network";
            disableDeletion = true;
            allowUiUpdates = false;
            options.path = ./dashboards;
          }
        ];
      };
    };
  };

  # Binding to the LAN address also prevents access through the WAN listener.
  networking.firewall.interfaces.vlan20.allowedTCPPorts = [ 3000 ];

  # Wait for the VLAN address before Grafana tries to bind its LAN listener.
  systemd.services.grafana = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };

  # The exporter module grants ambient NET_RAW, but its generic hardening
  # defaults to an empty bounding set. Permit just the ICMP capability.
  systemd.services.prometheus-blackbox-exporter.serviceConfig.CapabilityBoundingSet = [
    "CAP_NET_RAW"
  ];

  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    retentionTime = "30d";
    extraFlags = [ "--storage.tsdb.retention.size=2GB" ];
    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
    };
    exporters = {
      node = {
        enable = true;
        listenAddress = "127.0.0.1";
        enabledCollectors = [ "systemd" ];
        extraFlags = [
          "--collector.netdev.device-include=^(enp1s0|vlan10|vlan20)$"
          "--collector.systemd.unit-include=^(dnsmasq|stubby|qos-shaper|grafana|prometheus).*"
        ];
      };
      blackbox = {
        enable = true;
        listenAddress = "127.0.0.1";
        configFile = (pkgs.formats.yaml { }).generate "network-probes.yml" {
          modules = {
            icmp_ipv4 = {
              prober = "icmp";
              timeout = "3s";
              icmp.preferred_ip_protocol = "ip4";
            };
            dns_local = {
              prober = "dns";
              timeout = "3s";
              dns = {
                transport_protocol = "udp";
                preferred_ip_protocol = "ip4";
                query_name = "example.com";
                query_type = "A";
                valid_rcodes = [ "NOERROR" ];
                validate_answer_rrs.fail_if_none_matches_regexp = [
                  ".+[[:space:]]+IN[[:space:]]+A[[:space:]]+.+"
                ];
              };
            };
          };
        };
      };
    };
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [ { targets = [ "127.0.0.1:9100" ]; } ];
      }
      {
        job_name = "prometheus";
        static_configs = [ { targets = [ "127.0.0.1:9090" ]; } ];
      }
      {
        job_name = "internet-icmp";
        metrics_path = "/probe";
        params.module = [ "icmp_ipv4" ];
        static_configs = [
          {
            targets = [ "1.1.1.1" ];
            labels.destination = "Cloudflare";
          }
          {
            targets = [ "9.9.9.9" ];
            labels.destination = "Quad9";
          }
        ];
        relabel_configs = [
          {
            source_labels = [ "__address__" ];
            target_label = "__param_target";
          }
          {
            source_labels = [ "__param_target" ];
            target_label = "instance";
          }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:9115";
          }
        ];
      }
      {
        job_name = "router-dns";
        metrics_path = "/probe";
        params.module = [ "dns_local" ];
        static_configs = [ { targets = [ "127.0.0.1:53" ]; } ];
        relabel_configs = [
          {
            source_labels = [ "__address__" ];
            target_label = "__param_target";
          }
          {
            source_labels = [ "__param_target" ];
            target_label = "instance";
          }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:9115";
          }
        ];
      }
    ];
  };
}
