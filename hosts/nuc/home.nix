{
  config,
  pkgs,
  inputs,
  ...
}:
{

  imports = [
    ../../modules/home/profiles/base.nix
    ../../modules/home/profiles/server.nix
    ../../modules/home/codex/playwright.nix
    (inputs.shared-nvim + "/home-manager/nvim.nix") # moved to a flake
    ../../modules/home/git.nix
  ];

  beads.localServer = true;

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.05"; # Please read the comment before changing.

}
