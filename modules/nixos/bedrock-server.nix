{ config, pkgs, ... }: 
let
  configDir = "/var/lib/bedrock-data";
in {

  systemd.tmpfiles.rules = [
    "d ${configDir} 0755 root root - -"
  ];

  virtualisation.podman.enable = true;

  virtualisation.oci-containers.containers."bedrock-server" = {
    image = "itzg/minecraft-bedrock-server:latest";
    autoStart = true;
    ports = [ "19132:19132/udp" ];
    volumes = [
      "${configDir}:/data"
    ];
    environment = {
      EULA = "TRUE";
    };

  };


  networking.firewall.allowedUDPPorts = [ 19132 ];
}
