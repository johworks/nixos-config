{ config, pkgs, inputs, ... }:

{

  imports = [
    inputs.nixarr.nixosModules.default
  ];

  users.users.jellyfin.extraGroups = [ "render" "video" ];  # renderD128 access

  systemd.services.jellyfin.serviceConfig = {
    DeviceAllow = [ "/dev/dri/renderD128" "/dev/dri/card1" ];
    BindPaths = [ "/dev/dri" ];
    SupplementaryGroups = [ "render" "video" ];
  };

  networking.firewall.allowedTCPPorts = [ 8096 5055 8989 7878 9696 8787 9091 ];

  nixarr = {
    enable = true;

    jellyfin.enable = true;          # 8096
    jellyseerr.enable = true;        # 5055

    radarr.enable = true;            # 8989
    sonarr.enable = true;            # 7878
    prowlarr.enable = true;          # 9696
    readarr.enable = true;           # 8787

    # This is broken for some group reason
    #readarr-audiobook.enable = true; # 9494

    vpn = {
      enable = true;
      wgConf = "/data/.secret/wg.conf";
    };


    # Turn this off for now. I don't need to get anything new
    transmission = {
      enable = false;
      vpn.enable = true;
      peerPort = 2529;
    };

    mediaDir = "/data/media";
    stateDir = "/data/media/.state/nixarr";
  };

}
