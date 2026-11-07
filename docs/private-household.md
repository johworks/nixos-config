# Private household configuration

The public flake provides `nuc-without-household` for independent evaluation.
The production `nuc` output lives in the private household flake, which imports
that base and the Home Assistant modules. Do not activate the public-only base
on the NUC: it does not contain Home Assistant. Use the private checkout and its
locked public input for NUC builds and activation.

Private repository access is needed on any machine evaluating that flake.
Private Git hosting limits source access, but Nix copies flake inputs and generated
configuration into the locally readable Nix store. Credentials must remain in
SOPS files or other runtime secret storage, never in ordinary Nix or YAML values.
Removing files from the current public tree does not remove earlier Git history.

The automated update preparer cannot yet compose the private NUC configuration;
see [automated updates](automated-updates.md). Its NUC runs fail closed.
