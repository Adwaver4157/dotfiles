# Fresh machine bootstrap

## 0. Clone (HTTPS)

```bash
git clone https://github.com/Adwaver4157/dotfiles.git ~/dotfiles
cd ~/dotfiles
```
(Private repo → `gh auth login` first, or use a Personal Access Token.)

`install.sh` is idempotent — safe to re-run. It backs up any pre-existing real
files to `*.bak.<TS>` and leaves existing symlinks alone.

---

## macOS

Prerequisite — Homebrew (interactive sudo, so not scripted):
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

```bash
cd ~/dotfiles && ./install.sh
```
Runs `brew bundle` from `Brewfile` (CLI tools, casks incl. kitty/aerospace/
fuse-t/fonts, VS Code extensions, go/npm globals), installs pixi + Claude Code;
stows `zsh aerospace ssh-macos` + the shared set
(`claude tmux bin kitty nvim starship ssh`).

Post-install:
```bash
exec zsh
# in tmux: prefix(C-a) + I   to install plugins
# nvim: plugins auto-install on first launch (pinned by nvim-pack-lock.json)
```

---

## Linux GPU box (bash)

### System prerequisites (sudo; a GPU box usually has these)
- `git`, `curl`
- **NVIDIA driver + Docker + nvidia-container-toolkit** (for `--gpus all` / compose GPU).
  Rootless Docker recommended (agent's `docker` can't become host root).
- GitHub access for `git pull` (HTTPS; a PAT only if the repo is private or you push).

### Install
```bash
cd ~/dotfiles && ./install.sh
```
On Linux this:
- installs **pixi** + the CLI toolset (ripgrep/fd/fzf/zoxide/bat/eza/lazygit/gh/nvim/
  tmux/starship/ruff/uv/… **+ xclip, sshfs**) — no brew, no sudo,
- installs **Claude Code** (`curl claude.ai/install.sh`),
- stows **`bash`** + the shared set (`claude tmux bin nvim starship ssh`; `kitty`
  is a harmless unused symlink on a headless box),
- wires `~/.ssh/config` Include (ControlMaster + keepalive) and tpm.

Your previous `~/.bashrc` is backed up to `~/.bashrc.bak.<TS>` — merge anything you
need into `~/.bashrc.local`.

### Post-install
```bash
exec bash                      # or re-login
claude                         # log in. agent teams auto mode needs Anthropic API + Claude Code v2.1.83+ / Opus 4.6+ or Sonnet 4.6
# in tmux: prefix(C-a) + I     # install plugins
```
Optional:
```bash
npm i -g @openai/codex && codex login          # for the codex-fallback (cross-model)
docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi   # verify GPU
```
Machine-local config in `~/.bashrc.local` (e.g. `echo "sk-ant-..." > ~/.anthropic_api_key`, CUDA paths).

### daily-report on a remote box

The skill runs wherever Claude Code runs — session transcripts live on THAT
machine, so a remote session's report must be generated on the remote.

```bash
cd ~/dotfiles && git pull && ./install.sh      # deploy/refresh ~/.claude/skills
echo 'export TZ=Asia/Tokyo' >> ~/.bashrc.local # servers default to UTC; without
                                               # this, JST morning work (before
                                               # 09:00) buckets into yesterday's
                                               # report date
```

Notion sync needs a Notion MCP connector, which headless boxes usually lack —
answer `skip` on the first `/daily-report` run (writes per-project `DISABLED`;
nothing is asked again). Reports land in `<project>/.claude/daily-reports/` —
commit them to the project repo or read them over ssh; sync to Notion from the
Mac if wanted. Container sessions (ml-gpu template): the skill must also be
visible in the CONTAINER's `~/.claude` (the `claude_config` volume) — check
`ls ~/.claude/skills` inside before relying on it.

### Then develop
```bash
cd ~/work/parent && tmux new -A -s dev && claude     # auto mode; multi-project per docs/agent-teams.md §C
```

---

## Notes
- **push is manual** (deny `git push:*`); HTTPS push needs a PAT / credential helper.
- pixi tool install is **non-fatal** — it warns and continues if a package name
  differs on this platform; install those few by hand.
- macOS uses **zsh**, Linux uses **bash** — two shell configs by design (some alias
  duplication, no `chsh`/zsh-install needed on servers).
