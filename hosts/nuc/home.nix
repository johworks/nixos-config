{ config, pkgs, pkgsLatest, inputs, ... }:
#let
#  gruvboxPlus = import ../../modules/home/gruvbox-plus.nix { inherit pkgs; };
#in 
{

  imports = [
    ../../modules/home/profiles/base.nix
    ../../modules/home/profiles/server.nix
    (inputs.shared-nvim + "/home-manager/nvim.nix")  # moved to a flake
    ../../modules/home/firefox.nix
    ../../modules/home/git.nix
    ../../modules/home/ssh.nix
    ../../modules/home/brave.nix
  ];

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = config.profiles.basePackages ++ (with pkgs; [
    sops
    # Interact with iCloud photos
    pkgsLatest.icloudpd
  ]);

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.05"; # Please read the comment before changing.

  # Let Home Manager install and manage itself.
  # Moved to base.nix
  # programs.home-manager.enable = true;
}
