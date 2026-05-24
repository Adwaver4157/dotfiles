# Agent teams — autonomous dev (mac local & remote GPU Docker)

How to run **Claude Code agent teams in auto mode** for hands-off development, in
two environments:
- **A. mac (local)** — no Docker; OS + worktree + auto-mode classifier as the guard.
- **B. remote GPU Ubuntu (Docker)** — the **training container is the sandbox**
  (see `project-templates/ml-gpu/`).

## How agent teams work (common)

- Enabled by `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` + `teammateMode: "auto"`
  (both in `claude/.claude/settings.json`).
- **Requirements** (else `mode: auto` is rejected): Claude Code v2.1.83+, model
  Sonnet 4.6 / Opus 4.6 / Opus 4.7, **Anthropic API** (not Bedrock/Vertex), and on
  Team/Enterprise an admin must enable auto mode.
- **Trigger**: just ask — "○○を実装して", "agent team で進めて", "リファクタして".
  The `agent-team` skill then runs: `TeamCreate` → investigator-planner (writes
  `PLAN.md`, `mode:auto`) → per-task implementers + `reviewer` + `smoke-tester`
  spawned in parallel (`mode:auto`) coordinating via `SendMessage`. Size floor:
  use it only for ≥3 files or ≥2 phases.
- `teammateMode: auto` → teammates appear as **tmux split panes** (you're always
  in tmux), so you can watch each one live.

## The safety distinction that matters: `auto` vs `bypassPermissions`

| Mode | deny rules | Extra guard | Use |
|---|---|---|---|
| **auto** (agent teams) | **Enforced — resolve first** | Classifier blocks force-push, push-to-`main`, `curl\|bash`, data exfil, prod deploy, mass delete; broad allow rules (`Bash(*)`, `Bash(python*)`, `Agent`) are dropped; stated boundaries ("don't push") honored | **Default for autonomous work** |
| **bypassPermissions** = `--dangerously-skip-permissions` | **NOT enforced — permission layer skipped entirely** (only `rm -rf /`,`rm -rf ~` still prompt) | none; no prompt-injection protection | **Container/VM only** |

> ⚠️ Correction to a common belief: **deny does NOT survive `--dangerously-skip-permissions`.**
> Your `Bash(git push:*)` deny protects you in **auto mode**, but is bypassed
> under full YOLO. Prefer auto mode; reserve YOLO for inside the container, where
> the boundary (no creds → push can't authenticate) is the real protection.

## A. mac (local)

No Docker. Isolation = git worktree + auto-mode (deny + classifier). Never use
`--dangerously-skip-permissions` on the bare host (no boundary).

```bash
# optional: isolate so agents can't touch your main checkout
git worktree add ../myrepo-agent -b agent/feature
cd ../myrepo-agent
claude                       # you're in tmux
```
Then ask for the work ("認証まわりを実装して"). The skill spawns teammates as
tmux panes in **auto mode**:
- deny (`git push:*`, `rm -rf`, `sudo`, …) is enforced; the classifier blocks
  risky escalations. If a teammate is blocked 3× in a row, auto mode pauses and
  prompts you.
- Review diffs, then **you** commit/push manually (agents can't push).
- Optional hardening: `/sandbox` (macOS Seatbelt) confines Bash at the OS level —
  no Docker needed.

## B. remote GPU Ubuntu (Docker)

Isolation = the **training container** (`project-templates/ml-gpu/`). Persistence
across SSH drops = run Claude inside the **container's own tmux**; the container
stays up regardless of your SSH connection.

```bash
# 1. connect (ControlMaster + keepalive come from ssh/.ssh/config.d)
ssh gpu-box

# 2. in the project: copy the ml-gpu template files in, keep settings.json deny
#    in sync, then build (settings.json is baked into the image)
docker compose -f docker-compose.yml -f docker-compose.claude.yml build \
  --build-arg UID=$(id -u)

# 3. start the container detached (survives disconnect)
docker compose -f docker-compose.yml -f docker-compose.claude.yml up -d claude

# 4. enter the container's tmux and launch Claude
docker exec -it project-claude tmux new -A -s dev
#   inside container tmux:
claude            # first run: authenticate (claude_config volume persists OAuth)
```
Then drive the agent team:
- **Default — auto mode**: ask for the work; deny (`git push:*`) + classifier are
  enforced. The container adds defense-in-depth (data `:ro`, no creds, no
  `docker.sock`). This is the recommended setting.
- **Fully unattended — YOLO**: `claude --dangerously-skip-permissions` is
  acceptable **here** because the container is the boundary. Note: **deny is OFF
  in this mode** — safety comes from data `:ro` + no credentials (push can't
  authenticate) + no `docker.sock` + non-root `developer` user, NOT from the deny
  list. (Claude refuses `--dangerously-skip-permissions` as root; the template's
  non-root user is why it works.)

**GPU-thrifty staged debugging** (tell the team): CPU+fake data shape check →
small real data 10 iters on GPU (no NaN) → only then full config 1 epoch. Real
GPU only at the last stage. (Details in `project-templates/ml-gpu/README.md`.)

**Reconnect after an SSH drop** — nothing is lost:
```bash
ssh gpu-box
docker exec -it project-claude tmux attach -t dev
```
**Cleanup** when done: the skill shuts teammates down + `TeamDelete`; then
`docker compose -f ... -f docker-compose.claude.yml down`.

## C. Multiple projects under one parent (mixed Docker)

When you work across several projects in one parent dir and only *some* operations
need Docker, don't containerize the coordinator — **run Claude on the host in the
parent dir** so agent teams can see and coordinate all projects, and launch
per-project Docker only when a task needs it.

- **Boundary = auto mode** (classifier + deny), not a container. Run as non-root;
  never `--dangerously-skip-permissions` on the host. Prefer **rootless Docker** so
  the agent's `docker` can't become host root.
- **Write the topology down**: put a parent `CLAUDE.md` describing the projects,
  their dependencies, which use Docker, and cross-project conventions — agents
  can't coordinate what they can't see. Template:
  `project-templates/multi-project/CLAUDE.template.md`. Add a per-project
  `CLAUDE.md` with that project's build/test/docker commands and image name.

```bash
ssh gpu-box
cd ~/work/parent          # parent of project-a, project-b, project-c
tmux new -A -s dev
claude                    # auto mode; planner surveys all 3, decomposes cross-project tasks
```
- Docker-needing ops: the agent runs `docker compose -f project-b/docker-compose.yml up -d`
  on demand. Non-Docker projects are edited directly.
- Heavy/risky single-project ops (long training): the host coordinator launches that
  project's **ml-gpu container** (`docker compose -f project-b/docker-compose.claude.yml run ...`)
  — the container is the boundary for that op, the host stays the coordinator.
- auto-mode `deny` (`git push:*`) holds; pre-allow common docker subcommands
  (`Bash(docker compose up:*)`) to cut interruptions (broad allows are dropped in
  auto mode, narrow ones carry over).

### sshfs — use it for the remote loop?

**No, not as the main surface.** For remote GPU dev the compute (build / test / git /
docker / GPU) must run **where the GPU is**, so run Claude **on the remote**. sshfs
only mounts files onto your mac: `git`/`ripgrep`/builds over sshfs are slow, and the
GPU isn't reachable from a local Claude. Use sshfs (or `vdd`) only for incidental
browsing/copying of outputs; for editing prefer remote `nvim` or Remote-SSH. Never
run a local Claude against an sshfs mount for GPU work.

## Quick reference

| | Do | Don't |
|---|---|---|
| Mode | `auto` (deny + classifier) for most work | `--dangerously-skip-permissions` on a bare host |
| YOLO | only inside the GPU container | rely on deny under YOLO (it's off) |
| Push | push manually yourself | mount `~/.ssh`/creds into the container |
| Watch | tmux panes (teammateMode auto) | run agent teams for 1–2 file edits (size floor) |
