---
description: "やりたいことを伝えると、この環境(dotfiles)設定に最適な進め方(マシン/権限モード/サンドボックス/テンプレ/具体コマンド)を提案する。Recommend the best concrete workflow for a described task given this setup."
---

The user will describe something they want to do (e.g. "train project-b on the GPU
box", "refactor across these 3 projects", "try a risky migration"). **Recommend the
single best concrete way to run it** on this machine's setup. Be decisive — give one
recommendation with exact commands, not a menu of options.

## What this environment provides

- Shell/tools: zsh + starship, **pixi** (brew still present during transition), tmux,
  nvim, kitty, aerospace.
- Claude: **agent teams enabled** (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`,
  `teammateMode: auto`). The `agent-team` skill runs planner → parallel per-task
  implementers + reviewer + smoke-tester in `mode: auto` (size floor: ≥3 files or
  ≥2 phases). Permission **deny includes `git push:*`** — push is always manual.
- `/commit` generates a concise one-line Conventional Commit.
- ssh config has ControlMaster + keepalive (`ssh/.ssh/config.d`).

## Decision framework (apply this)

**1. Which machine?**
- **mac (local)** — no Docker dev here. Isolation = `git worktree` + auto mode
  (classifier + deny). Optionally `/sandbox` (Seatbelt, Bash-only). **Never**
  `--dangerously-skip-permissions` on the mac host.
- **remote GPU Ubuntu** — for anything needing GPU/Docker. Connect via ssh, work
  inside a **remote tmux** (survives disconnect).

**2. Single project vs multiple?** (remote)
- **Single project + Docker** → the **training container is the boundary**
  (`project-templates/ml-gpu/`): `docker compose ... run claude`; inside, auto mode
  keeps deny, and `--dangerously-skip-permissions` is acceptable *only inside the
  container*.
- **Multiple projects under one parent / Docker only for some ops** → run Claude on
  the **host in the parent dir** (`project-templates/multi-project/`), auto mode as
  the boundary, launch per-project Docker on demand (rootless preferred). Topology
  goes in a parent `CLAUDE.md`.

**3. Permission mode**
- Default to **auto mode** (deny enforced + classifier blocks force-push/push-to-main/
  `curl|bash`/exfil/prod/mass-delete). Use it for almost everything.
- **`--dangerously-skip-permissions` skips deny entirely → only inside a container/VM.**
  Never on a bare host.

**4. sshfs?** Only for incidental file browsing — never as the surface for remote GPU
dev (compute must run where the GPU is; run Claude on the remote, not local-over-sshfs).

## How to respond

1. If env is unclear, ask **1-3 short questions**: mac or remote-GPU? needs Docker/GPU?
   single or multi-project? any untrusted code?
2. Then give a **decisive** recommendation:
   - where to run (mac / remote host / inside which container),
   - permission mode (auto vs YOLO-in-container) and a one-line why,
   - isolation (worktree / ml-gpu container / host+auto / multi-project parent),
   - which template to copy (if any),
   - the **exact startup commands** (ssh, tmux, docker compose, `claude`, and the
     trigger phrase for the agent-team skill),
   - one safety note (push is manual; deny/auto caveats).
3. Keep it short and concrete. Prefer auto mode; reserve YOLO for inside a container.

The task: $ARGUMENTS
