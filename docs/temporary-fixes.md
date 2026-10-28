# Temporary fixes and their retirement

These entries track workarounds that need reconsideration, not a list of every
security setting. Beads is the authority for ownership, evidence, and review
dates. The inventory links the code to those tasks and explains what a safe
removal must preserve.

## Review process

- When adding a temporary fix, create an open Beads task with the label
  `temporary-fix`, a due date, the reason, affected hosts, and an observable
  removal test. Add it to this inventory and link the task from the code when
  useful. Do not treat a deliberate ongoing policy as a temporary patch.
- Review the relevant entries whenever their flake inputs, package versions,
  or upstream sources change, and at least every 30 days while they remain.
  Find them with `bd list --label temporary-fix`. The due dates make them
  visible in Beads; they do not themselves send a notification or run a review.
- Claim the task before investigating. Record the checked revisions, relevant
  upstream evidence, actual tests, result and any limitations in its notes.
  If the fix remains necessary or the result is inconclusive, leave the task
  open, set its next due date with `bd update <id> --due +30d`, and release the
  claim. Never infer safety from a version number alone.
- To retire a fix, test a candidate without that specific workaround, build
  and check the affected configurations, and verify the behavior below. Keep
  the task open if a required runtime or physical-host check is unavailable.
  Remove the entry and close the task only after the removal is verified;
  checkpoint Beads with `bd dolt commit` after the completed work.

Weekly update preparation records this inventory in its local `report.json` as
**not reviewed**. It does not check upstream, run the retirement tests, or
change Beads. A successful build or status-only Signal message is not a review.

## Current inventory

| Beads task | Workaround and reason | Evidence needed before retirement |
| --- | --- | --- |
| `nixos-6y3` | `scripts/nixos-lab/qemu.nix` backports QEMU's EGL cleanup fix for the lab's 11.1.2, which crashed on exit with the desktop Radeon. | Confirm the selected QEMU source contains equivalent cleanup, then test real accelerated process exits and guest shutdown/restart in both labs. The version guard skips other versions; review an update rather than assuming they contain the fix. Existing runs keep their original launcher. |
| `nixos-gr8` | `modules/nixos/common/security.nix` rewrites standalone CA bundles, certifi, pip's bundle and Python ensurepip wheels in stable and unstable closures. | Trial removing each replacement independently and test the actual unmodified runtimes, including fresh venvs: all affected chains must be rejected and ordinary HTTPS must work. Preserve the intentional system distrust policy. Investigate older dependency copies separately under `nixos-nzf`; see the [security audit](security-audit-2026-10-22.md) and [desktop verification](security-upgrade-desktop-2026-10.md). |
| `nixos-07j` | The same module substitutes Electron 42; `hosts/desktop/home.nix` makes OpenCode's embedded Bun use the filtered system CA store. | Test each unmodified runtime independently against the affected chains and a successful ordinary HTTPS control, including Electron's relevant application mode. Preserve equivalent trust behavior. |
| `nixos-ufs` | `modules/nixos/stremio/stremio.nix` runs a maintained native runtime and enforces FFmpeg TLS verification and loopback binding. | Verify an alternative preserves verified TLS for redirects and nested media, loopback exposure, and actual playback/transcoding before removing the corresponding override. |
| `nixos-ei7` | `modules/nixos/matrix/matrix.nix` takes the Synapse module and packages from unstable on stable NUC; `hosts/desktop/configuration.nix` supplies a certificate for the r8125 module. | For Synapse, confirm stable supports the configured features and security requirements and verify messaging/calls and service behavior. For r8125, confirm upstream produces the required certificate and validate the physical desktop's Ethernet and Secure Boot. Review each independently. |

Explicit CA distrust, database major-version pins, local service bindings, and
other intentional policies are not automatically retired when a package is
updated. For the original security changes and limitations, see
[the desktop upgrade](security-upgrade-desktop-2026-10.md) and
[the NUC upgrade](security-upgrade-nuc-2026-10.md).
