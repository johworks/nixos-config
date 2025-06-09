{ config, pkgs, ... }:

{

  services.jellyfin = {
    enable = true;
    openFirewall = true;
    user = "john";  # PUID/PGID 1000
    group = "users";

    # Apparently optional (/dev/dri will be auto-detected?)
    #extraPackages = [ pkgs.vaapiIntel pkgs.intel-media-driver ];

    environment = {
      TZ = "America/New_York";
    };

    # Config location: /var/lib/jellyfin
    dataDir = "/var/lib/jellyfin";

  };

  systemd.services.jellyfin.serviceConfig = {
    #DeviceAllow = [ "/dev/dri" ];
    #SupplementaryGroups = [ "video" ];
    # Binds this into the services namespace (just like docker!)
    BindPaths = [
      "/media/john/ToshibaHDD/data/media:/data/media"
    ];
  };

  # HTTP and HTTPS
  networking.firewall.allowedTCPPorts = [ 8096 8920 ];

}
