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
    environment = {
      TZ = "America/New_York";
      WEBPASSWORD = "admin";  # Change this!
      FTLCONF_dns_upstreams = "1.1.1.1;9.9.9.9";
    };
    volumes = [
      "${configDir}/etc-pihole:/etc/pihole"
      "${configDir}/etc-dnsmasq.d:/etc/dnsmasq.d"
    ];
    extraOptions = [ 
      "--cap-add=NET_ADMIN"
      "--cap-add=NET_RAW"
      "--network=host"
    ];
  };

  networking.firewall.allowedUDPPorts = [ 53 67 ];
  networking.firewall.allowedTCPPorts = [ 53 67 80 443 ];

}
