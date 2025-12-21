{ config, pkgs, ... }:

{
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "pcie_aspm=off" ];

  hardware.graphics = { # opengl
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
    ];
  };

  # Pull in special ethernet kernel module
  boot.extraModulePackages = [ config.boot.kernelPackages.r8125 ]; # official realtek one
  boot.blacklistedKernelModules = [ "r8169" ]; # r8125 rev 0xc is too new
  hardware.enableAllFirmware = true; # Attempt to get ethernet firmware pulled in
}
