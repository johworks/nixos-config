{ config, lib, pkgs, ... }:
{
  imports = [
    ../theme.nix
  ];

  # Shared Home Manager defaults for every host. Override with lib.mkForce
  # in downstream profiles or host modules when a machine needs a different
  # value, e.g.
  #   home.sessionVariables.EDITOR = lib.mkForce "helix";
  
  options = {
    # Default packages for all configs
    profiles.basePackages = lib.mkOption {
      type = with lib.types; listOf package;
      default = with pkgs; [ gnumake tree sops nodejs ];
    };
  };

  config = {

    home.username = lib.mkDefault "john";
    home.homeDirectory = lib.mkDefault "/home/john";

    home.sessionVariables = lib.mkDefault {
      EDITOR = "nvim";
    };

    # Needed for npm/codex as well
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

    home.file.".ssh/known_hosts".text = lib.mkDefault ''
        github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
        github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
        github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
      '';

    programs.home-manager.enable = lib.mkDefault true;
  };
}
