{ config, ... }:

let
  turnDomain = "turn.goobhub.org";
  externalIp = "96.252.115.76";
  listenIp = "192.168.1.247";
in
{
  sops.secrets."coturn-static-auth-secret" = {
    sopsFile = ./secrets/secrets.yaml;
    owner = "turnserver";
    group = "turnserver";
    mode = "0400";
    path = "/run/secrets/coturn-static-auth-secret";
  };

  sops.templates."matrix-turn-config.yaml" = {
    owner = "matrix-synapse";
    group = "matrix-synapse";
    mode = "0400";
    content = ''
      turn_shared_secret: "${config.sops.placeholder."coturn-static-auth-secret"}"
    '';
  };

  services.coturn = {
    enable = true;
    no-cli = true;
    no-tcp-relay = true;
    use-auth-secret = true;
    static-auth-secret-file = config.sops.secrets."coturn-static-auth-secret".path;
    realm = turnDomain;
    listening-ips = [ listenIp ];
    relay-ips = [ listenIp ];
    extraConfig = ''
      external-ip=${externalIp}/${listenIp}
      no-multicast-peers
    '';
  };

  services.matrix-synapse = {
    extraConfigFiles = [ config.sops.templates."matrix-turn-config.yaml".path ];
    settings = {
      turn_uris = [
        "turn:${turnDomain}:3478?transport=udp"
        "turn:${turnDomain}:3478?transport=tcp"
      ];
      turn_user_lifetime = "1h";
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 3478 ];
    allowedUDPPorts = [ 3478 ];
    allowedUDPPortRanges = [
      {
        from = 49152;
        to = 65535;
      }
    ];
  };
}
