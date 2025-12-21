{
  # Create dir for mount
  systemd.tmpfiles.rules = [
    "d /data 0775 root media -"
    "d /data/.secret 0775 root media -"

    "d /data/media 0775 root media -"
    "d /data/media/.state 0775 root media -"

    "d /etc/wireguard 0775 root root -"
  ];

  # Mount the USB HDD (root:media)
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/3c4c7e33-f992-4295-9ec2-2f954fe77c27";
    fsType = "ext4";
    options = [ "defaults" ];
  };
}
