# ML/GPU project template — Claude Code (agent teams) in a Docker sandbox

Run Claude Code and **agent teams** safely on a GPU box by using your **existing
training Docker image as the sandbox**. No microVM, no nested sandbox.

> Copy this folder's files into a project and adjust paths/image names. These are
> reference templates, not stowed into `$HOME`.

## Why the container, not sbx / built-in `/sandbox`

- **sbx (Docker Sandboxes)** — microVM based → GPU passthrough isn't clean
  (Docker intentionally omits CUDA userspace/drivers from the microVM).
- **built-in `/sandbox` (Seatbelt / bubblewrap)** — incompatible with the
  `docker` command itself; `enableWeakerNestedSandbox` weakens it, defeating the point.

For GPU + Docker dev, drop the "wrap a sandbox around it" idea — the **training
container itself is the boundary**.

## Pick a pattern

| Pattern | When | File |
|---|---|---|
| **A. devcontainer** | VSCode/Cursor, IDE-integrated | `.devcontainer/devcontainer.json` |
| **B. compose service** | already on compose; long YOLO / agent-teams runs | `docker-compose.claude.yml` |
| **C. host Claude + `docker exec`** | container stays up; drive from host | `claude-exec.sh` |

Short HIL cycles → **A or C**. Long agent-teams parallel runs → **B**.

## Safety checklist (every pattern)

- Mount data **`:ro`**. Writable outputs (checkpoints, logs) go to separate `rw` dirs.
- **Never mount** `~/.ssh`, `~/.aws`, `/var/run/docker.sock` — mounting any of these voids the boundary.
- `.git` handling:
  - subdir-only mount → git unusable inside (safe, harder to debug)
  - repo-root mount → convenient, but push risk
  - push needs auth; if no credentials enter the container, push can't do damage.
    Deny `git push` for belt-and-suspenders.
- `deny` rules (incl. `git push:*`) are enforced in **auto mode** but **NOT under
  `--dangerously-skip-permissions`** (that mode skips the permission layer entirely).
  The bundled `settings.json` is **baked into the image** by `Dockerfile.claude`'s
  `COPY`, so the deny list exists in auto mode even though `claude_config` starts
  empty. Under full YOLO the real boundary is the **container itself** (data `:ro`,
  no creds → push can't authenticate, no `docker.sock`, non-root user). Keep the
  deny list in sync with your dotfiles `claude/.claude/settings.json` (statusLine/
  hooks are omitted here since those files aren't baked). See `docs/agent-teams.md`.

## GPU-thrifty staged debugging

Tell Claude to compress real-GPU runs to the last 1–2 stages:

```
1. CPU + fake data (batch=2, random) → forward/backward shape integrity
2. small real data, 10 iters on GPU → no NaN loss
3. only if still failing: full config, 1 epoch
4. each stage fails → isolate cause → fix → retest
```

Real GPU runs only at the last stage → saves cost and time.

## Quick start (pattern B)

```bash
export WANDB_API_KEY=...  ANTHROPIC_API_KEY=...     # optional; compose reads them
docker compose -f docker-compose.yml -f docker-compose.claude.yml run --rm claude bash
# inside the container:
claude
```
If your host UID isn't 1000, build with `--build-arg UID=$(id -u)` so mounted
files aren't root-owned.
