{ config, pkgs, ... }:

let
  myDomain = "stream.goobhub.org";
  stremioPort = 11470;
  configDir = "/var/lib/stremio";
in
{
  systemd.tmpfiles.rules = [
    "d ${configDir} 0755 root root - -"
  ];

  virtualisation.podman.enable = true;

  virtualisation.oci-containers.containers.stremio = {
    image = "stremio/server:latest";
    autoStart = true;
    ports = [ "127.0.0.1:${toString stremioPort}:${toString stremioPort}" ];
    volumes = [
      "${configDir}:/root/.stremio-server"
    ];
  };

  services.nginx = {
    enable = true;
    virtualHosts."${myDomain}" = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString stremioPort}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host              $host;
          proxy_set_header X-Real-IP         $remote_addr;
          proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };
}
