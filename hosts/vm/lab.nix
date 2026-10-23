{
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];

  networking.hostName = lib.mkForce "hyprland-lab";
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
    # The launcher supplies a per-run loopback SSH forward and display backend.
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
  services.displayManager.autoLogin = {
    enable = true;
    user = "john";
  };
  # This disposable console login has no access to a real user's credentials.
  users.users.john.initialPassword = "lab";
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = [
    "root"
    "john"
  ];

  services.openssh = {
    enable = true;
    hostKeys = [
      {
        path = "/etc/ssh/lab_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AuthorizedKeysFile = "/etc/ssh/lab_authorized_keys";
      AllowUsers = [ "john" ];
    };
  };

  # Only fresh lab keys cross the boundary, via QEMU firmware files, not shares.
  # Pinning the injected host key avoids trusting an SSH keyscan on first boot.
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
    wtype
    python3
    curl
  ];
  home-manager.users.john = {
    wayland.windowManager.hyprland.settings.monitor = lib.mkForce [ ",1600x900@60,auto,1" ];
    # Tracking stays on the host, without granting the guest the NUC SSH key.
    systemd.user.services.beads-tunnel = lib.mkForce { };
  };
}
