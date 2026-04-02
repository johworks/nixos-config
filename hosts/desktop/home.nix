{ config, pkgs, inputs, ... }:

{
  imports = [
    ../../modules/home/profiles/base.nix
    ../../modules/home/firefox.nix
    ../../modules/home/git.nix
    ../../modules/home/ssh.nix
    (inputs.shared-nvim + "/home-manager/nvim.nix")
  ];

  # Reuse the shared CLI base so desktop gets the same Codex/npm tooling as nuc.
  home.packages = config.profiles.basePackages;

  home.stateVersion = "25.11";
}
