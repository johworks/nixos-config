{
  config,
  pkgs,
  inputs,
  ...
}:

let
  domain = "goobhub.org";
  matrixRtcDomain = "matrix-rtc.${domain}";
  turnDomain = "turn.${domain}";
  myAcmeEmail = "viridianveil@protonmail.com";
  rtcPkgs = import inputs.nixpkgs-latest {
    inherit (pkgs) system;
  };
in
{
  sops.secrets."matrix-rtc-livekit-secret" = {
    sopsFile = ./secrets/secrets.yaml;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.templates."matrix-rtc-livekit-key-file" = {
    owner = "root";
    group = "root";
    mode = "0400";
    content = ''
      lk-jwt-service: ${config.sops.placeholder."matrix-rtc-livekit-secret"}
    '';
  };

  services.livekit = {
    enable = true;
    package = rtcPkgs.livekit;
    keyFile = config.sops.templates."matrix-rtc-livekit-key-file".path;
    settings = {
      port = 7880;
      room.auto_create = false;
      rtc = {
        tcp_port = 7881;
        port_range_start = 50000;
        port_range_end = 60000;
        # Diagnostic: prefer local interface candidates so LAN clients do not
        # need to hairpin through the public WAN address.
        use_external_ip = false;
        # Podman bridge addresses are not reachable by clients and just add
        # noise to ICE candidate gathering.
        ips.excludes = [ "10.88.0.0/16" ];
      };
      # MatrixRTC media flows through LiveKit, so use its embedded TURN
      # instead of a separate coturn service.
      turn = {
        enabled = true;
        domain = turnDomain;
        udp_port = 3478;
      };
    };
  };

  services.lk-jwt-service = {
    enable = true;
    package = rtcPkgs."lk-jwt-service";
    keyFile = config.sops.templates."matrix-rtc-livekit-key-file".path;
    livekitUrl = "wss://${matrixRtcDomain}/livekit/sfu";
    port = 8080;
  };

  systemd.services.lk-jwt-service = {
    wants = [
      "livekit.service"
      "matrix-synapse.service"
    ];
    after = [
      "livekit.service"
      "matrix-synapse.service"
    ];
    environment.LIVEKIT_FULL_ACCESS_HOMESERVERS = domain;
  };

  services.nginx = {
    enable = true;
    virtualHosts.${matrixRtcDomain} = {
      enableACME = true;
      forceSSL = true;

      locations."/livekit/jwt/" = {
        proxyPass = "http://127.0.0.1:8080";
        recommendedProxySettings = true;
        extraConfig = ''
          rewrite ^/livekit/jwt/(.*)$ /$1 break;
        '';
      };

      locations."/livekit/sfu/" = {
        proxyPass = "http://127.0.0.1:7880";
        proxyWebsockets = true;
        recommendedProxySettings = true;
        extraConfig = ''
          rewrite ^/livekit/sfu/(.*)$ /$1 break;
          proxy_send_timeout 120s;
          proxy_read_timeout 120s;
          proxy_buffering off;
          proxy_set_header Accept-Encoding gzip;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
        '';
      };
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = myAcmeEmail;
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 7881 ];
    allowedUDPPorts = [ 3478 ];
    allowedUDPPortRanges = [
      {
        from = 50000;
        to = 60000;
      }
    ];
  };
}
