{ lib, ... }:
{
  # Keep workstation systems tidy without hiding the policy in ad hoc host settings.
  nix.gc = {
    automatic = lib.mkDefault true;
    dates = lib.mkDefault "weekly";
    options = lib.mkDefault "--delete-older-than 14d";
  };

  nix.optimise.automatic = lib.mkDefault true;
}
