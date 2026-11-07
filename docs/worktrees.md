# Task worktrees

Use one task, one owner, one worktree, and one branch for repository changes.
The primary checkout stays on `main` and is reserved for integration. All new
task worktrees live in `/home/john/nixos-config/.worktrees/`; never create them
in `/tmp`. This directory is ignored by Git. Existing worktrees elsewhere need
a separate ownership audit before migration or removal.

## Find and claim work

Run `bd ready --json`, then `bd list --limit 0` to inspect outstanding tasks,
including in-progress and blocked work. Search descriptions as well as titles
for the feature, host, service, and likely modules; read likely matches with
`bd show <id>`. Use status-specific listings if filters hide outstanding work.
Beads does not automatically detect semantic overlap.

- Same outcome: reuse the existing task. If claimed, coordinate with its owner
  instead of taking over or creating a competing implementation.
- Depends on unfinished work: record a dependency with `bd dep add <id> <blocker>`.
  Work only on independent portions until the dependency is resolved.
- Related but independent: cross-reference task IDs in notes and describe each
  task's boundary. File overlap is a clue, not an exclusive file reservation.

Claim with `bd update <id> --claim`. Record intended outcome, affected areas,
owner, branch, absolute worktree path, and related tasks using
`bd update <id> --append-notes '...'`. Repeat overlap discovery when scope changes.
See [shared Beads state](beads.md) for actor identity and database handling.
If Beads is unavailable, record this information in the session handoff and
coordinate with other owners before overlapping work; reconcile it when restored.

## Create and work

Choose a descriptive slug. For example, replace these values before use:

```sh
repo=/home/john/nixos-config
task=nixos-EXAMPLE
slug=short-description
branch="feat/$task-$slug"
worktree="$repo/.worktrees/$task-$slug"
```

Under the integration lock described below, fetch origin, ensure the primary
checkout is clean and on `main`, and fast-forward it with
`git -C "$repo" merge --ff-only origin/main`. If histories diverge, stop and
resolve ownership/integration history; do not reset main. Then create:

```sh
git -C "$repo" worktree add "$worktree" -b "$branch" main
```

Release the lock before development. Run edits, builds, and commits from the
task worktree with an explicit working directory. Do not reuse another task's
branch or worktree. Add new flake inputs to Git's index with `git add -N` before
evaluation. Keep task metadata in the shared Beads database; do not initialize
another database. Worktrees share refs and Git configuration, so avoid changing
repository-wide settings for an individual task.

Worktrees do not isolate VM slots, ports, running services, or host activation.
Coordinate those separately and follow the existing lab and activation rules.

## Integrate one task at a time

All agents using this clone must use the same advisory lock. Derive its path
from Git's common directory, not the task worktree's `.git` file:

```sh
common=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)
exec 9>"$common/agent-integration.lock"
flock -n 9
```

Proceed only if `flock` succeeds. If busy, end that shell and retry later while
continuing independent work. Keep the descriptor open in the **same shell** for
the entire sequence below; separate tool calls do not preserve shell locks.
Use one shell script or a persistent shell session. Release with `flock -u 9`
and `exec 9>&-`, or exit the shell. Never delete the lock file to unlock it;
process exit releases the lock even after a crash.

1. Confirm both checkouts are clean, the primary is on `main`, and the task
   worktree is on the expected branch. Fetch origin and fast-forward primary
   main to `origin/main`. Stop on unexpected changes or divergent history.
2. In the task worktree, merge current main: `git merge main`. Resolve conflicts
   there and commit the resolution. Merging avoids rewriting shared commits.
3. Validate the combined result using checks appropriate to the changes.
   For configuration changes, follow repository evaluation and lab requirements;
   always run `nix --store daemon flake check --no-write-lock-file` before switching.
   Documentation-only changes need diff/link/command review, not a system build.
4. With checks passing and a clean task worktree, run
   `git -C "$repo" merge --ff-only "$branch"`. Record the integrated commit and
   checks in Beads. No PR is required. Push only when the task/session calls for
   it; never force-push. A rejected push requires fetching and revalidating any
   newly combined changes, not overwriting remote work.
5. Release the lock after integration (and publication, when applicable).

If conflicts or failures need extended work, release the lock and resolve them
in the task worktree. Reacquire it and restart the sequence before integrating.
Preliminary testing can happen outside the lock, but final validation must cover
the current combined result. This prevents concurrent edits to main's index and
another agent advancing main between validation and integration.

The lock is local to this clone. For work on multiple hosts or separate clones,
designate one integration clone/owner in Beads and send branches there; local
locks do not serialize remote pushes. All participants must follow the protocol.

## Finish or pause

Before cleanup, verify the expected branch is checked out in your task worktree,
`git status --porcelain --untracked-files=all` is empty there, and:

```sh
git -C "$repo" merge-base --is-ancestor "$branch" main
```

Inspect ignored files as well (`git status --short --ignored`): preserve useful
artifacts outside the worktree before removal. Stop task-owned processes using
the directory. From outside the worktree, remove only the verified task:

```sh
cd "$repo"
git worktree remove "$worktree"
git branch -d "$branch"
bd close "$task" --reason 'Integrated, verified, and worktree cleaned up'
bd dolt commit
```

Do not use force removal, `git branch -D`, bulk deletion, or age-based cleanup.
Remote branch deletion is separate and requires checking that nobody uses it.
If cleanup fails, retain the task's path and reason in Beads for follow-up.

For paused work, commit useful non-secret progress and record the current commit,
remaining checks, dependencies, owner, and retention reason in Beads. Leave the
branch and worktree intact. A handoff must explicitly transfer ownership; an old
timestamp or idle agent is not evidence that work is disposable.
