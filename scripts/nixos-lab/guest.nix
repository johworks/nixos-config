{
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];

  virtualisation = {
    cores = 4;
    memorySize = 8192;
    diskSize = 65536;
    useBootLoader = true;
    useEFIBoot = true;
    mountHostNixStore = false;
    useHostCerts = false;
    sharedDirectories = lib.mkForce { };
    restrictNetwork = true;
    qemu.forceAccel = true;
    qemu.options = [
      "-vga none"
      "-device virtio-vga-gl"
    ];
    resolution = {
      x = 1600;
      y = 900;
    };
  };
  boot.kernelModules = [ "qemu_fw_cfg" ];
  boot.loader.timeout = lib.mkForce 1;
  services.spice-vdagentd.enable = lib.mkForce false;
  security.sudo.wheelNeedsPassword = false;
  services.openssh = {
    enable = true;
    hostKeys = [
      {
        path = "/etc/ssh/lab_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      PasswordAuthentication = lib.mkForce false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AuthorizedKeysFile = "/etc/ssh/lab_authorized_keys";
    };
  };
  systemd.services.lab-access = {
    wantedBy = [ "multi-user.target" ];
    before = [ "sshd.service" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -m 0644 /sys/firmware/qemu_fw_cfg/by_name/opt/hyprlab.authorized-key/raw /etc/ssh/lab_authorized_keys
      install -m 0600 /sys/firmware/qemu_fw_cfg/by_name/opt/hyprlab.host-key/raw /etc/ssh/lab_host_ed25519_key
    '';
  };
  systemd.services.sshd.requires = [ "lab-access.service" ];
  environment.systemPackages = with pkgs; [
    grim
    python3
  ];
}
