{config, pkgs, ...}: 
let
  configDir = "/var/lib/pihole";
in 
{

  #systemd.tmpfiles.rules = [
  #  "d ${configDir}/etc-pihole 0755 root root - -"
  #  "d ${configDir}/etc-dnsmasq.d 0755 root root - -"
  #];

  ## Set this box as the router
  #environment.etc."pihole-dnsmasq.d/99-gateway.conf".text = ''
  #  dhcp-option=option:router,192.168.10.2
  #'';

  ## Make sure pihole doesn't bind to wg, only LAN
  #environment.etc."pihole-dnsmasq.d/01-bind.conf".text = ''
  #  interface=enp1s0
  #  bind-interfaces
  #'';

  systemd.tmpfiles.rules = [
    "d ${configDir}/etc-pihole 0755 root root - -"
    "d ${configDir}/etc-dnsmasq.d 0755 root root - -"
    "f ${configDir}/etc-dnsmasq.d/99-gateway.conf 0644 root root - dhcp-option=option:router,192.168.10.2"
    "f ${configDir}/etc-dnsmasq.d/01-bind.conf 0644 root root - interface=192.168.10.2\nbind-interfaces"
  ];

  virtualisation.podman.enable = true;

  # Podman container
  virtualisation.oci-containers.containers.pihole = {
    image = "pihole/pihole:latest";
    environment = {
      TZ = "America/New_York";
      WEBPASSWORD = "admin";  # Change this!
      FTLCONF_dns_upstreams = "1.1.1.1;9.9.9.9";
      WEB_PORT = "8000";
    };
    volumes = [
      "${configDir}/etc-pihole:/etc/pihole"
      "${configDir}/etc-dnsmasq.d:/etc/dnsmasq.d"
      #"/etc/pihole-dnsmasq.d/99-gateway.conf:/etc/dnsmasq.d/99-gateway.conf:ro"
      #"/etc/pihole-dnsmasq.d/01-bind.conf:/etc/dnsmasq.d/01-bind.conf:ro"
    ];
    #ports = [
    #  "53:53/tcp"
    #  "53:53/udp"
    #  "67:67/tcp"
    #  "67:67/udp"
    #  "80:80/tcp"
    #  "443:443/tcp"
    #];
    extraOptions = [ 
      "--cap-add=NET_ADMIN"
      "--cap-add=NET_RAW"
      "--network=host"
    ];
  };

  networking.firewall.allowedUDPPorts = [ 53 67 ];
  networking.firewall.allowedTCPPorts = [ 53 67 8000 ];

}
