# multi-project template

Coordinate several projects under one parent dir with Claude **agent teams (auto
mode)** on a remote host — when only *some* projects/ops use Docker.

## Use

1. Copy `CLAUDE.template.md` to your parent dir **as `CLAUDE.md`** and fill in the
   project table + how they connect.
2. (optional) add a per-project `CLAUDE.md` with that project's build/test/docker
   commands and image name.
3. On the remote host:
   ```bash
   cd ~/work/parent
   tmux new -A -s dev
   claude            # auto mode; ask for the cross-project work
   ```

## Why host (not a container) here

Agent teams must see all projects to coordinate them, and no single base image
fits all three. The **boundary is auto mode** (classifier + deny incl. `git push:*`),
not a container. Launch per-project Docker only for ops that need it; run heavy
single-project training inside that project's `../ml-gpu/` container.

Full rationale + commands: see [`docs/agent-teams.md`](../../docs/agent-teams.md) §C.
