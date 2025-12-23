{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    # Reuse the laptop Home Manager profile to mirror the desktop setup in the VM.
    ../laptop/home.nix
  ];

  # VM display defaults to 1440p to match the host monitor and avoid 4:3 scaling.
  wayland.windowManager.hyprland.settings.monitor =
    lib.mkForce [ ",2560x1440@60,auto,1" ];
}
