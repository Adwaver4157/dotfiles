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

```bash
cd ~/dotfiles && ./install.sh
```
Installs pixi + CLI tools, Claude Code; stows `zsh aerospace` + the shared set
(`claude tmux bin kitty starship ssh`).

Post-install:
```bash
exec zsh
brew install starship zsh-autosuggestions zsh-syntax-highlighting   # prompt + suggestions
# in tmux: prefix(C-a) + I   to install plugins
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
- stows **`bash`** + the shared set (`claude tmux bin starship ssh`; `kitty` is a
  harmless unused symlink on a headless box),
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
