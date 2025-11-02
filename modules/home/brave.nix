{config, pkgs,  ... }:

{
  programs.brave = {
    enable = false;

    #extensions = with pkgs; [
    #  ublock-origin
    #  darkreader
    #  youtube-shorts-block
    #  sponsorblock
    #  bitwarden
    #];

  };

}
