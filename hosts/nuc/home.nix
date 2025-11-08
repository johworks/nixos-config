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
    # Moved to configuration.nix
    #../../modules/home/ssh.nix
    ../../modules/home/brave.nix
  ];

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = config.profiles.basePackages ++ (with pkgs; [
    sops
    # Interact with iCloud photos
    pkgsLatest.icloudpd
    nodejs  # needed for npm (OpenAI Codex)
  ]);

  programs.bash = {
    enable = true; 
    # We need this for all shell
    initExtra = ''
      # Load Home Manager session vars in interactive shells too
      if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      elif [ -f "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh" ]; then
        . "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh"
      fi
      '';
  };


  # Configure npm prefix via .npmrc
  home.file.".npmrc".text = ''
    prefix=${config.home.homeDirectory}/.npm-global
  '';

  # Add ~/.npm-global/bin to PATH for your user
  home.sessionPath = [
    "${config.home.homeDirectory}/.npm-global/bin"
  ];


  

  # Pull private flakes
  # home.sessionVariables.GIT_SSH_COMMAND = "ssh -i ~/.ssh/github_id_ed25519";

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
