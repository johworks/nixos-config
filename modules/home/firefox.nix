{ config, pkgs, inputs, ... }:
{
  programs.firefox = {
    enable = true;

    profiles.default = {
      # --- Privacy & UX hardening (balanced; avoids common site breakage) ---
      settings = {
        ##### Core privacy / tracking protection
        "browser.contentblocking.category" = "strict";
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "privacy.trackingprotection.cryptomining.enabled" = true;
        "privacy.trackingprotection.fingerprinting.enabled" = true;
        "privacy.trackingprotection.emailtracking.enabled" = true;
        "privacy.donottrackheader.enabled" = true;
        "privacy.query_stripping.enabled" = true;

        ##### HTTPS-Only
        "dom.security.https_only_mode" = true; # may affect some self-hosted apps

        ##### Cookies & history
        # 5 = partitioned third-party (DFPI); good balance vs breakage
        "network.cookie.cookieBehavior" = 5;
        "signon.rememberSignons" = false;

        ##### Telemetry / experiments / promotions
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.unified" = false;
        "datareporting.healthreport.uploadEnabled" = false;
        "app.shield.optoutstudies.enabled" = false;
        "browser.ping-centre.telemetry" = false;
        "browser.newtabpage.activity-stream.feeds.snippets" = false;
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "extensions.pocket.enabled" = false;

        ##### UI niceties
        "browser.download.panel.shown" = true;
        "identity.fxaccounts.enabled" = false;

        ##### Dark mode (UI + page content)
        # Force browser UI to prefer dark:
        "ui.systemUsesDarkTheme" = 1;
        # Prefer dark for web content when sites support color-scheme:
        # 0=auto, 1=light, 2=dark, 3=browser; set to 2 to bias pages dark.
        "layout.css.prefers-color-scheme.content-override" = 2;

        ##### New tab layout (keep Topsites, remove the rest)
        "browser.newtabpage.activity-stream.feeds.topsites" = true;
        "browser.newtabpage.activity-stream.feeds.section.highlights" = false;
        "browser.newtabpage.activity-stream.feeds.section.recommendationProvider" = false;
      };

      # --- Search engines ---
      search = {
        default = "ddg";   # make DuckDuckGo primary
        force = true;      # enforce our defaults (prevents Firefox from changing them)

        engines = {
          "ddg".metaData.hidden = false; # ensure visible even if Firefox tries to hide it

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

        # Optional: set explicit order in the search menu
        order = [ "ddg" "Nix Packages" ];
      };

      # --- Extensions ---
      extensions.packages = with inputs.firefox-addons.packages."x86_64-linux"; [
        #ublock-origin
        adnauseam
        darkreader
        youtube-shorts-block
        sponsorblock
        bitwarden
        decentraleyes
        privacy-badger
      ];
    };
  };
}

