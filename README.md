# dotfiles

Cross-platform (macOS + Linux) dev setup managed with **GNU stow** + **pixi**,
with Claude Code global config. Inspired by a stow-based layout; carries my own
Brewfile-era tooling, Claude agent-team setup, kitty, aerospace, and tmux-dev.

## Layout

Each top-level directory is a **stow package** mirroring `$HOME`. `install.sh`
detects the OS and stows only the relevant packages.

| Scope | Packages |
|-------|----------|
| **Shared** | `claude`, `tmux`, `bin`, `kitty`, `starship` |
| **macOS only** | `zsh`, `aerospace` |
| **Linux only** | _(none yet — bash/etc. TODO)_ |

```
.
├── install.sh                  # idempotent pixi + stow installer
├── .stowrc                     # --no-folding (stow links files, not dirs)
├── docs/macos-extras.md        # GUI apps / VS Code / heavy brew pkgs (manual)
├── claude/.claude/             # → ~/.claude/
│   ├── CLAUDE.md  settings.json  statusline.js
│   ├── agents/                 # planner / tester / implementer / reviewer
│   ├── commands/  hooks/  skills/
├── tmux/.tmux.conf
├── zsh/.zshrc
├── kitty/.config/kitty/kitty.conf
├── starship/.config/starship.toml
├── aerospace/.aerospace.toml
└── bin/.local/bin/tmux-dev
```

## Install

```bash
git clone <your-dotfiles-repo> ~/dotfiles
cd ~/dotfiles && ./install.sh
```

`install.sh` is **safe to re-run**. It installs pixi + a global CLI toolset,
Claude Code, then `stow -R`s the OS-appropriate packages. Pre-existing real
files are timestamp-backed up (`*.bak.<TS>`); existing symlinks are left alone.

GUI apps, VS Code extensions, and heavy brew-only packages are **not** installed
by the script — see [`docs/macos-extras.md`](docs/macos-extras.md).

## What pixi installs

```
stow git curl wget jq bc tmux=3.4 nvim nodejs python=3.11
ripgrep fd-find fzf zoxide bat eza lazygit gh tree htop
ruff uv pre-commit stylua clang-format pandoc starship
```
(Linux also gets `xclip`.)

## Daily commands

| Command | Action |
|---------|--------|
| `tmux-dev [dir]` | 3-pane dev session (nvim / lazygit / claude) |
| `ts` | fzf-pick a project under `~/workspace ~/projects …` then `tmux-dev` |
| `z <name>` | zoxide jump |
| `mkcd`, `extract` | make+cd, smart archive extract |
| `/commit`, `/advise` | Claude slash commands: concise commit / recommend a workflow |

## Machine-local overrides

Never committed (gitignored):

- `~/.zshrc.local` — anyenv, `ANTHROPIC_API_KEY`, host-specific paths
- `~/.claude/settings.local.json` — per-machine Claude overrides

## Claude Code config (`claude/` package)

Manages `~/.claude/`: `CLAUDE.md`, `settings.json` (agent-teams + statusline +
format-on-write hook + security allow/deny), `statusline.js`, `agents/`,
`commands/`, `hooks/`, `skills/`. Runtime state (`projects/`, `todos/`,
`memory/`, `.credentials.json`, `settings.local.json`) stays per-machine via
`.gitignore`.

## Agent teams & sandboxing

- [`docs/agent-teams.md`](docs/agent-teams.md) — run **agent teams in auto mode**
  for autonomous dev: (A) mac local, (B) single-project remote GPU container,
  (C) multi-project remote host with on-demand Docker. Covers the `auto` vs
  `--dangerously-skip-permissions` deny distinction and the sshfs question.
- **`/advise <task>`** — unsure how to run something? Describe it and Claude
  recommends the best machine / permission mode / sandbox / template / commands
  for this setup.
- **Codex cross-model fallback** (`codex-fallback` skill) — in agent-team runs, if the
  reviewer flags the same spot 3×, the lead escalates that scoped fix to Codex
  (`codex-fix`); a final `codex-review` cross-model pass runs at the end.

## Project templates

Reference templates to copy into projects (not stowed):

- `project-templates/ml-gpu/` — run Claude Code / **agent teams** safely on a GPU
  box by using the **existing training Docker container as the sandbox** (sbx's
  microVM can't do GPU passthrough; the built-in `/sandbox` is incompatible with
  `docker`). Patterns A (devcontainer) / B (compose) / C (`docker exec`) +
  safety checklist + GPU-thrifty staged debugging.
- `project-templates/multi-project/` — coordinate **several projects under one
  parent** with agent teams (auto mode) on a remote host, launching per-project
  Docker only when needed. Parent `CLAUDE.template.md` captures the topology.

## Uninstall

```bash
cd ~/dotfiles && ./install.sh --uninstall   # stow -D the packages
```

## Notes

- **Neovim** is managed separately (live `~/.config/nvim`), not yet a package
  here. Add as a stow package or git submodule when ready.
- Pre-reorg originals are archived under `.archive/pre-reorg/` (gitignored).
