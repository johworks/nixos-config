{ config, pkgs, inputs, ... }: 
{
  # Setup firefox; Move to it's own file soon
  programs.firefox = {
    enable = true;
    profiles.default = {

      settings = {
        "dom.security.https_only_mode" = true;  # This might break self-hosted apps
        "browser.download.panel.shown" = true;
        "identity.fxaccounts.enabled" = false;
        "signon.remeberSignons" = false;
        # Remove sponsored bs
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        # Disable snippets (Firefox promotional messages)
        "browser.newtabpage.activity-stream.feeds.snippets" = false;
        # Optional: Clean up new tab layout further
        "browser.newtabpage.activity-stream.feeds.topsites" = true;
        "browser.newtabpage.activity-stream.feeds.section.highlights" = false;
        "browser.newtabpage.activity-stream.feeds.section.recommendationProvider" = false;
      };

      search.engines = {
        "Nix Packages" = {
          urls = [{
            template = "https://search.nixos.org/packages";
            params = [
              { name = "type"; value = "packages"; }
              { name = "query"; value = "{searchTerms}"; }
            ];
          }];
          icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          definedAliases = [ "@np" ];
        };
      };
      search.force = true;

      extensions.packages = with inputs.firefox-addons.packages."x86_64-linux"; [
        ublock-origin
        darkreader
        youtube-shorts-block
        sponsorblock
        bitwarden
      ];
    };
  };
}
