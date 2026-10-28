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
    inputs.plasma-manager.homeModules.plasma-manager
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

  programs.plasma = {
    enable = true;
    # Set the count without replacing KWin's existing desktop IDs.
    configFile.kwinrc.Desktops.Number = 10;
    shortcuts = {
      kwin = {
        "Switch to Desktop 1" = [
          "Ctrl+F1"
          "Meta+1"
        ];
        "Switch to Desktop 2" = [
          "Ctrl+F2"
          "Meta+2"
        ];
        "Switch to Desktop 3" = [
          "Ctrl+F3"
          "Meta+3"
        ];
        "Switch to Desktop 4" = [
          "Ctrl+F4"
          "Meta+4"
        ];
        "Switch to Desktop 5" = "Meta+5";
        "Switch to Desktop 6" = "Meta+6";
        "Switch to Desktop 7" = "Meta+7";
        "Switch to Desktop 8" = "Meta+8";
        "Switch to Desktop 9" = "Meta+9";
        "Switch to Desktop 10" = "Meta+0";
        # KWin uses the shifted symbol for these shortcuts on the US layout.
        "Window to Desktop 1" = [ ];
        "Window to Desktop 2" = [ ];
        "Window to Desktop 3" = [ ];
        "Window to Desktop 4" = [ ];
        "Window to Desktop 5" = [ ];
        "Window to Desktop 6" = [ ];
        "Window to Desktop 7" = [ ];
        "Window to Desktop 8" = [ ];
        "Window to Desktop 9" = [ ];
        "Window to Desktop 10" = [ ];
        "Move and follow to desktop 1" = "Meta+!";
        "Move and follow to desktop 2" = "Meta+@";
        "Move and follow to desktop 3" = "Meta+#";
        "Move and follow to desktop 4" = "Meta+$";
        "Move and follow to desktop 5" = "Meta+%";
        "Move and follow to desktop 6" = "Meta+^";
        "Move and follow to desktop 7" = "Meta+&";
        "Move and follow to desktop 8" = "Meta+*";
        "Move and follow to desktop 9" = "Meta+(";
        "Move and follow to desktop 10" = "Meta+)";
        view_actual_size = [ ];
      };
      plasmashell = {
        "activate task manager entry 1" = [ ];
        "activate task manager entry 2" = [ ];
        "activate task manager entry 3" = [ ];
        "activate task manager entry 4" = [ ];
        "activate task manager entry 5" = [ ];
        "activate task manager entry 6" = [ ];
        "activate task manager entry 7" = [ ];
        "activate task manager entry 8" = [ ];
        "activate task manager entry 9" = [ ];
      };
    };
  };

  programs.plasma.configFile.kwinrc.Plugins.move-followEnabled = true;
  xdg.dataFile."kwin/scripts/move-follow".source = ./kwin-move-follow;

  home.packages = [
    secureOpencode
    pkgs.kdePackages.elisa
  ];

  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/grokbot" = [ "grok-bot.desktop" ];
    "x-scheme-handler/sand" = [ "grok-bot.desktop" ];
  };

  # Preserve host keys learned by SSH instead of replacing them with the shared list.
  home.file.".ssh/known_hosts".enable = false;

  home.file."${config.xdg.userDirs.desktop}/steam.desktop" = {
    source = "${osConfig.programs.steam.package}/share/applications/steam.desktop";
    executable = true;
  };

  home.stateVersion = "25.11";
}
