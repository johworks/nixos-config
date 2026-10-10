# Shared Beads state

The NUC runs Dolt on `127.0.0.1:3307`, with persistent data in
`/var/lib/beads-dolt`. Workstations forward `127.0.0.1:13307` to that listener
through SSH. All clones of this project use the `nixos_config` database.
Code branches do not create separate task databases.

`services.beadsDolt.enable = true` in the NUC configuration declares the
service, account, state directories, database initialization, and backup timer.
On first startup the service creates the database using this repo's project
identity. Later starts verify the existing database without reinitializing it.
Its service-owned client configuration lives in `/var/lib/beads-dolt-client`.
Initialization failures stop startup; they never trigger a database reset.

The shared Home Manager profile installs a `bd` wrapper around the Beads
package from the locked unstable input, including on the stable NUC.
It selects the server connection and disables Beads' automatic server startup.
If the NUC is unavailable, commands fail rather than creating local task state.

## Host setup

Rebuild the NUC first, then the client host:

```sh
sudo nixos-rebuild switch --flake .#nuc
sudo nixos-rebuild switch --flake .#desktop # or laptop / vm
```

Each client needs `/home/john/.ssh/id_ed25519_nuc` and the NUC's host key in
its SSH known hosts. The key must be authorized for `john` on the NUC.
The `beads-tunnel` user service starts at login and reconnects after network
interruptions. Missing keys cause the service to skip startup.

```sh
ssh -o BatchMode=yes nuc true
systemctl --user restart beads-tunnel
systemctl --user status beads-tunnel
bd list
```

The NUC connects directly and does not run the tunnel. To inspect its server:

```sh
ssh nuc systemctl status beads-dolt
ssh nuc journalctl -u beads-dolt -n 30 --no-pager
```

This project's `.beads/metadata.json` and `.beads/config.yaml` are tracked.
A fresh clone with that metadata connects immediately; it does not need
`bd bootstrap` or `bd init`. There is no task-state push/pull step.
Run `chmod 700 .beads` after cloning to use Beads' recommended permissions.

For a different project, initialize its own database with a unique name and
prefix. Beads 1.0.3 may stage and commit its generated files during init:

```sh
bd init --server --external --database another_project --prefix another \
  --skip-hooks --skip-agents --non-interactive
```

Add that project's database to the backup configuration before relying on it.

## Agent workflow

```sh
bd ready --json
bd update <id> --claim
bd show <id>
bd close <id> --reason "Implemented and verified"
```

Claims operate on the same live database across hosts. The wrapper defaults
the actor to `<hostname>:<CODEX_THREAD_ID>`, or `<hostname>:<user>` outside
Codex. Other concurrent agents on one host should set a distinct `BEADS_ACTOR`.
An explicit `BEADS_ACTOR` or `--actor` overrides the default.

Updates are immediately visible to other clients. Server mode leaves changes
in Dolt's durable working set; use `bd dolt commit` to create a history
checkpoint after a completed unit of work. Automatic JSONL exports and Git
backups are disabled for this repo, since the server owns the task state.

## Backups and recovery

`beads-dolt-backup.timer` makes a daily incremental Dolt backup of
`nixos_config` in `/var/lib/beads-dolt-backup/nixos_config`. This includes
history and uncommitted working-set changes and uses SQL against the running
server. It is on the NUC's disk; copy the backup off the NUC for recovery from
disk loss. Additional project databases need their own backup destinations.

```sh
ssh nuc sudo systemctl start beads-dolt-backup
ssh nuc systemctl status beads-dolt-backup.timer
```

Restore to a new directory using the same Dolt version, from a directory
outside the running server's data tree:

```sh
dolt config --global --add user.name "Beads recovery"
dolt config --global --add user.email "beads@localhost"
dolt backup restore file:///path/to/copied/nixos_config nixos_config_restored
```

Stop the service before replacing its database with a verified restored copy.
Never copy or modify the live `.dolt` internals while the server is running.
