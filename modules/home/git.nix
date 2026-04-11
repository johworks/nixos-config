{ lib, options, ... }:
let
  gitSettings = {
    init.defaultBranch = "main";
    core.editor = "nvim";
    pull.rebase = true;
  };
in
{
  # Keep one module working across the newer laptop/desktop Home Manager and the
  # older stable Home Manager used on the NUC.
  programs.git =
    {
      enable = true;
    }
    // lib.optionalAttrs (options.programs.git ? settings) {
      settings = gitSettings // {
        user.name = "John";
        user.email = "jworks2507@gmail.com";
      };
    }
    // lib.optionalAttrs (!(options.programs.git ? settings)) {
      userName = "John";
      userEmail = "jworks2507@gmail.com";
      extraConfig = gitSettings;
    };
}
