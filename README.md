# dotfiles

Cross-platform (macOS + Linux) dev setup managed with **GNU stow**, with Claude
Code global config. Tools come from the **`Brewfile` on macOS** and **pixi
global on Linux**; pixi also drives per-project envs everywhere. Carries the
Claude agent-team setup, kitty, aerospace, nvim (kickstart-based), and tmux-dev.

## Layout

Each top-level directory is a **stow package** mirroring `$HOME`. `install.sh`
detects the OS and stows only the relevant packages.

| Scope | Packages |
|-------|----------|
| **Shared** | `claude`, `tmux`, `bin`, `kitty`, `nvim`, `starship`, `ssh` |
| **macOS only** | `zsh`, `aerospace`, `ssh-macos` |
| **Linux only** | `bash` |

```
.
├── install.sh                  # idempotent installer (brew bundle / pixi + stow)
├── Brewfile                    # macOS tools: formulae, casks, VS Code, go/npm
├── .stowrc                     # --no-folding (stow links files, not dirs)
├── docs/macos-extras.md        # Homebrew / fuse-t / kitty-adoption notes
├── claude/.claude/             # → ~/.claude/
│   ├── CLAUDE.md  settings.json  statusline.js
│   ├── agents/                 # planner / tester / implementer / reviewer
│   ├── commands/  hooks/  skills/
├── nvim/.config/nvim/          # kickstart.nvim-based (init.lua + lock file)
├── tmux/.tmux.conf
├── zsh/.zshrc
├── kitty/.config/kitty/kitty.conf
├── starship/.config/starship.toml
├── aerospace/.aerospace.toml
└── bin/.local/bin/              # tmux-dev, rdp-ssh, codex-fix, codex-review
```

## Install

```bash
git clone https://github.com/Adwaver4157/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install.sh
```
Fresh-machine steps (macOS & Linux GPU box, incl. GPU prerequisites): see
[`docs/bootstrap.md`](docs/bootstrap.md).

`install.sh` is **safe to re-run**. It installs the toolset (macOS: `brew
bundle` from `Brewfile`; Linux: pixi global), Claude Code, then `stow -R`s the
OS-appropriate packages. Pre-existing real files are timestamp-backed up
(`*.bak.<TS>`); existing symlinks and stow-managed dirs are left alone.

## Where tools come from

- **macOS — [`Brewfile`](Brewfile)**: CLI formulae, GUI casks (aerospace, kitty,
  utm, fuse-t, fonts, …), VS Code extensions, go/npm globals. Homebrew itself
  is a manual prerequisite — see [`docs/macos-extras.md`](docs/macos-extras.md).
  After changing tools: `brew bundle dump --file=~/dotfiles/Brewfile --force`
  and commit.
- **Linux — pixi global** (no sudo, no brew):

  ```
  stow git curl wget jq bc tmux=3.4 nvim nodejs python=3.11
  ripgrep fd-find fzf zoxide bat eza lazygit gh tree htop
  ruff uv pre-commit stylua clang-format pandoc starship xclip sshfs
  ```

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

- **Neovim** (`nvim/` package) is a [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim)
  snapshot plus local additions (smart-splits, oil.nvim); plugin versions are
  pinned by `nvim-pack-lock.json`. Upstream kickstart updates are merged by hand.
- Pre-reorg originals are archived under `.archive/pre-reorg/` (gitignored).
