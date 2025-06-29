{config, pkgs, ...}: 
let
  configDir = "/var/lib/pihole";
in 
{

  systemd.tmpfiles.rules = [
    "d ${configDir}/etc-pihole 0755 root root - -"
    "d ${configDir}/etc-dnsmasq.d 0755 root root - -"
  ];

  virtualisation.podman.enable = true;

  # Podman container
  virtualisation.oci-containers.containers.pihole = {
    image = "pihole/pihole:latest";
    ports = [ "53:53/udp" "53:53/tcp" "80:80" ];
    environment = {
      TZ = "America/New_York";
      WEBPASSWORD = "admin";  # Change this!
    };
    volumes = [
      "${configDir}/etc-pihole:/etc/pihole"
      "${configDir}/etc-dnsmasq.d:/etc/dnsmasq.d"
    ];
    extraOptions = [ "--cap-add=NET_ADMIN" ];
  };

}
