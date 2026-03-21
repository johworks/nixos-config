{ config, pkgs, inputs, ... }:

{
  imports = [
    ../../modules/home/profiles/base.nix
    ../../modules/home/firefox.nix
    ../../modules/home/git.nix
    ../../modules/home/ssh.nix
    (inputs.shared-nvim + "/home-manager/nvim.nix")
  ];

  home.stateVersion = "25.11";
}
