{
  config,
  pkgs,
  inputs,
  osConfig,
  ...
}:

let
  opencode = inputs.nixpkgsOpencode.legacyPackages.${pkgs.stdenv.hostPlatform.system}.opencode;
  secureOpencode = pkgs.symlinkJoin {
    name = "opencode-${opencode.version}";
    paths = [ opencode ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # OpenCode's embedded Bun otherwise retains its independent CA bundle.
    postBuild = ''
      wrapProgram "$out/bin/opencode" \
        --set SSL_CERT_FILE ${osConfig.security.pki.caBundle} \
        --set SSL_CERT_DIR ${builtins.dirOf osConfig.security.pki.caBundle}
    '';
  };
in
{
  imports = [
    ../../modules/home/profiles/base.nix
    ../../modules/home/profiles/desktop.nix
    ../../modules/home/codex/playwright.nix
    ../../modules/home/update-preparation.nix
    ../../modules/home/firefox.nix
    ../../modules/home/git.nix
    ../../modules/home/ssh.nix
    ./cellular-wallpaper.nix
    (inputs.shared-nvim + "/home-manager/nvim.nix")
  ];

  services.nixosUpdatePreparation.enable = true;

  # Reuse the shared CLI base so desktop gets the same Codex/npm tooling as nuc.
  home.packages = config.profiles.basePackages ++ [
    secureOpencode
  ];

  # Preserve host keys learned by SSH instead of replacing them with the shared list.
  home.file.".ssh/known_hosts".enable = false;

  home.file."${config.xdg.userDirs.desktop}/steam.desktop" = {
    source = "${osConfig.programs.steam.package}/share/applications/steam.desktop";
    executable = true;
  };

  home.stateVersion = "25.11";
}
