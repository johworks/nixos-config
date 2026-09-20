{
  config,
  pkgs,
  inputs,
  osConfig,
  ...
}:

{
  imports = [
    ../../modules/home/profiles/base.nix
    ../../modules/home/profiles/desktop.nix
    ../../modules/home/firefox.nix
    ../../modules/home/git.nix
    ../../modules/home/ssh.nix
    (inputs.shared-nvim + "/home-manager/nvim.nix")
  ];

  # Reuse the shared CLI base so desktop gets the same Codex/npm tooling as nuc.
  home.packages = config.profiles.basePackages;

  # Preserve host keys learned by SSH instead of replacing them with the shared list.
  home.file.".ssh/known_hosts".enable = false;

  home.file."${config.xdg.userDirs.desktop}/steam.desktop" = {
    source = "${osConfig.programs.steam.package}/share/applications/steam.desktop";
    executable = true;
  };

  home.stateVersion = "25.11";
}
