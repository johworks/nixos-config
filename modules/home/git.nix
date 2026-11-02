{ lib, options, ... }:
let
  gitEmail = "githubcommits.credibly138@passinbox.com";
  gitSettings = {
    init.defaultBranch = "main";
    core.editor = "nvim";
    pull.rebase = true;
  };
in
{
  # Keep one module working across the newer laptop/desktop Home Manager and the
  # older stable Home Manager used on the NUC.
  programs.git = {
    enable = true;
  }
  // lib.optionalAttrs (options.programs.git ? settings) {
    settings = gitSettings // {
      user.name = "John";
      user.email = gitEmail;
    };
  }
  // lib.optionalAttrs (!(options.programs.git ? settings)) {
    userName = "John";
    userEmail = gitEmail;
    extraConfig = gitSettings;
  };
}
