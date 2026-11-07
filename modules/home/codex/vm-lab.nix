{
  inputs,
  pkgs,
  ...
}:
let
  lab = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.nixos-lab;
in
{
  home.packages = [ lab ];

  # The sandbox hides KVM/render devices. Trust this immutable launcher outside
  # it as the ordinary user, never sudo or a mutable checkout's Python script.
  # This is a trusted-flake workflow, not isolation from malicious Nix inputs.
  home.file.".codex/rules/nixos-vm-lab.rules".text = ''
    prefix_rule(
        pattern = ["${lab}/bin/nixos-lab"],
        decision = "allow",
        justification = "Control isolated lab guests as the host user; sudo is guest-only. Use trusted local flakes.",
        match = [
            "${lab}/bin/nixos-lab --flake .#desktop start",
            "${lab}/bin/nixos-lab --flake .#desktop exec --root -- id",
        ],
        not_match = [
            "sudo ${lab}/bin/nixos-lab --flake .#desktop start",
            "python3 scripts/nixos-lab/lab.py --flake .#desktop start",
            "/tmp/nixos-lab/bin/nixos-lab --flake .#desktop start",
        ],
    )
  '';
}
