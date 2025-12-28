{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    # Reuse the laptop Home Manager profile to mirror the desktop setup in the VM.
    ../laptop/home.nix
  ];

}
