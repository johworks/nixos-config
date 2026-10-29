{ config, pkgs, ... }:

{

  services.jellyfin = {
    enable = true;
    openFirewall = true;
    # Config location: /var/lib/jellyfin
    dataDir = "/var/lib/jellyfin";

  };

  systemd.services.jellyfin.serviceConfig = {
    Environment = "TZ=America/New_York";
    SupplementaryGroups = [ "video" "media" ];
    # Binds this into the services namespace (just like docker!)
    BindReadOnlyPaths = [
      "/data/media"
    ];
  };

  # HTTP and HTTPS
  networking.firewall.allowedTCPPorts = [ 8096 8920 ];

}
