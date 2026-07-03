#!/usr/bin/env bash
# Idempotent dotfiles installer (Brewfile on macOS, pixi on Linux, GNU stow).
# Safe to re-run from any partial state. Each step is a no-op if already
# satisfied.
#
#   1. Install pixi (if missing; used for per-project envs on both OSes)
#   2. Tools: macOS → `brew bundle` from ./Brewfile (CLI + casks + VS Code +
#      go/npm globals); Linux → pixi global install <tools>
#   3. Install Claude Code (if `claude` not on PATH)
#   4. git submodule update --init --recursive (no-op if no submodules)
#   5. Pre-create ~/.config, ~/.local, ~/.claude as REAL dirs (stow folds at
#      file level thanks to .stowrc --no-folding)
#   6. Backup any pre-existing real files that would conflict (timestamped)
#   7. stow -R the OS-appropriate packages
#   8. Install tpm (tmux plugin manager)
#
# Usage:
#   ./install.sh                # install / re-stow
#   ./install.sh --uninstall    # stow -D the same packages
#
# Cross-platform: macOS + Linux configs live side by side; the OS is detected
# here and only the relevant packages are stowed.
#
# Homebrew itself is NOT installed by this script (its installer needs an
# interactive sudo) — on a fresh Mac install it first, then re-run.

set -u

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
TS="$(date +%Y%m%d-%H%M%S)"

case "$(uname -s)" in
  Darwin) OS_KIND=macos ;;
  Linux)  OS_KIND=linux ;;
  *)      OS_KIND=unknown ;;
esac

# Stow packages: shared set + OS-specific set.
COMMON_PKGS=(claude tmux bin kitty nvim starship ssh)
case "$OS_KIND" in
  macos) OS_PKGS=(zsh aerospace ssh-macos) ;;
  linux) OS_PKGS=(bash) ;;        # Linux uses bash; macOS uses zsh
  *)     OS_PKGS=() ;;
esac
STOW_PKGS=("${COMMON_PKGS[@]}" "${OS_PKGS[@]}")

log()  { printf '\033[34m[*]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m[ok]\033[0m %s\n' "$*"; }
skip() { printf '\033[90m[skip]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[warn]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[31m[err]\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

#------------------------------------------------------------------------------
# 1. pixi
#------------------------------------------------------------------------------
ensure_pixi() {
  if have pixi; then
    skip "pixi already installed ($(pixi --version 2>/dev/null))"
  else
    log "Installing pixi"
    curl -fsSL https://pixi.sh/install.sh | bash && ok "pixi installed" || warn "pixi install failed"
  fi
  export PATH="$HOME/.pixi/bin:$PATH"
}

#------------------------------------------------------------------------------
# 2a. macOS tools via Homebrew Bundle (Brewfile = source of truth on macOS)
#------------------------------------------------------------------------------
ensure_brew_bundle() {
  [ "$OS_KIND" = macos ] || return 0
  if ! have brew; then
    warn "Homebrew not installed — install it first (https://brew.sh), then re-run:"
    warn '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    return
  fi
  log "brew bundle (Brewfile: CLI tools, casks, VS Code extensions, go/npm globals)"
  if brew bundle install --file="$DOTFILES_DIR/Brewfile" --no-upgrade; then
    ok "brew bundle"
  else
    warn "brew bundle had failures (continuing); re-run 'brew bundle --file=$DOTFILES_DIR/Brewfile' to retry"
  fi
}

#------------------------------------------------------------------------------
# 2b. Linux tools via pixi global (per-tool, individually idempotent)
#------------------------------------------------------------------------------
ensure_pixi_tools() {
  [ "$OS_KIND" = linux ] || { skip "pixi global tools (macOS uses Brewfile)"; return; }
  if ! have pixi; then warn "pixi not on PATH; skipping global tools"; return; fi
  local tools=(
    stow git curl wget jq bc tmux=3.4 nvim nodejs python=3.11
    ripgrep fd-find fzf zoxide bat eza lazygit gh tree htop
    ruff uv pre-commit stylua clang-format pandoc starship
  )
  [ "$OS_KIND" = linux ] && tools+=(xclip sshfs)
  log "Installing pixi global tools (idempotent per tool)"
  for t in "${tools[@]}"; do
    pixi global install "$t" >/dev/null 2>&1 && ok "$t" || warn "pixi global install $t failed (continuing)"
  done
}

#------------------------------------------------------------------------------
# 3. Claude Code
#------------------------------------------------------------------------------
ensure_claude_code() {
  if have claude; then skip "claude code already installed"; return; fi
  log "Installing Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash && ok "claude code installed" || warn "claude code install failed"
}

#------------------------------------------------------------------------------
# 4. git submodules (no-op if none)
#------------------------------------------------------------------------------
ensure_submodules() {
  [ -d "$DOTFILES_DIR/.git" ] || { warn "$DOTFILES_DIR is not a git repo; skipping submodules"; return; }
  [ -f "$DOTFILES_DIR/.gitmodules" ] || { skip "no submodules"; return; }
  log "Updating git submodules"
  git -C "$DOTFILES_DIR" submodule update --init --recursive && ok "submodules up to date" || warn "submodule update failed"
}

#------------------------------------------------------------------------------
# 5. Pre-create dirs that must stay REAL (so stow folds at file-level)
#------------------------------------------------------------------------------
ensure_real_dirs() {
  for d in "$HOME/.config" "$HOME/.local" "$HOME/.local/bin" "$HOME/.local/share" "$HOME/.local/state" "$HOME/.claude"; do
    if [ -L "$d" ]; then
      warn "$d is a symlink (likely stow-folded); replace with a real dir before re-stowing"
    else
      mkdir -p "$d"
    fi
  done
}

#------------------------------------------------------------------------------
# 6. Backup conflicting real files/dirs (skip existing symlinks)
#------------------------------------------------------------------------------
backup_if_real() {
  local p="$1"
  [ -L "$p" ] && return 0
  # A real dir already holding symlinks into the repo is stow-managed
  # (--no-folding keeps dirs real); backing it up would just churn on re-runs.
  if [ -d "$p" ] && find "$p" -maxdepth 3 -type l -lname "*dotfiles*" 2>/dev/null | grep -q .; then
    return 0
  fi
  if [ -e "$p" ]; then
    mv "$p" "${p}.bak.${TS}" && ok "backup: $p -> ${p}.bak.${TS}" || warn "backup failed for $p"
  fi
}

backup_existing_targets() {
  log "Backing up pre-existing real files (symlinks left alone)"
  backup_if_real "$HOME/.tmux.conf"
  backup_if_real "$HOME/.config/kitty/kitty.conf"
  backup_if_real "$HOME/.config/starship.toml"
  backup_if_real "$HOME/.local/bin/tmux-dev"
  backup_if_real "$HOME/.local/bin/rdp-ssh"
  backup_if_real "$HOME/.config/nvim"
  for f in CLAUDE.md settings.json statusline.js; do backup_if_real "$HOME/.claude/$f"; done
  for d in agents commands skills hooks; do backup_if_real "$HOME/.claude/$d"; done
  if [ "$OS_KIND" = macos ]; then
    backup_if_real "$HOME/.zshrc"
    backup_if_real "$HOME/.aerospace.toml"
  elif [ "$OS_KIND" = linux ]; then
    backup_if_real "$HOME/.bashrc"
  fi
}

#------------------------------------------------------------------------------
# 7b. Wire ~/.ssh/config to Include the managed config.d (idempotent, appends)
#------------------------------------------------------------------------------
ensure_ssh_include() {
  local cfg="$HOME/.ssh/config"
  mkdir -p "$HOME/.ssh/sockets"
  chmod 700 "$HOME/.ssh" "$HOME/.ssh/sockets" 2>/dev/null
  if [ -f "$cfg" ] && grep -q 'config\.d/\*\.conf' "$cfg" 2>/dev/null; then
    skip "~/.ssh/config already Includes config.d"
  else
    printf '\n# dotfiles: managed common settings (keep at END so per-host blocks above win)\nInclude ~/.ssh/config.d/*.conf\n' >> "$cfg"
    chmod 600 "$cfg" 2>/dev/null
    ok "added 'Include ~/.ssh/config.d/*.conf' to ~/.ssh/config"
  fi
}

#------------------------------------------------------------------------------
# 7. stow each package independently
#------------------------------------------------------------------------------
run_stow() {
  if ! have stow; then warn "stow not installed; run pixi tools step first"; return; fi
  log "Stowing $OS_KIND packages: ${STOW_PKGS[*]}"
  cd "$DOTFILES_DIR" || { err "cd $DOTFILES_DIR failed"; return; }
  for pkg in "${STOW_PKGS[@]}"; do
    [ -d "$pkg" ] || { warn "package '$pkg' not found; skipping"; continue; }
    if stow -R -t "$HOME" "$pkg" 2>/tmp/stow-${pkg}.err; then
      ok "stow $pkg"
    else
      warn "stow $pkg had conflicts; see /tmp/stow-${pkg}.err"
    fi
  done
}

run_unstow() {
  if ! have stow; then warn "stow not installed; nothing to remove"; return; fi
  log "Un-stowing $OS_KIND packages: ${STOW_PKGS[*]}"
  cd "$DOTFILES_DIR" || { err "cd $DOTFILES_DIR failed"; return; }
  for pkg in "${STOW_PKGS[@]}"; do
    [ -d "$pkg" ] || continue
    stow -D -t "$HOME" "$pkg" 2>/tmp/unstow-${pkg}.err && ok "unstow $pkg" || warn "unstow $pkg had issues; see /tmp/unstow-${pkg}.err"
  done
}

#------------------------------------------------------------------------------
# 8. tpm
#------------------------------------------------------------------------------
ensure_tpm() {
  if [ -d "$HOME/.tmux/plugins/tpm" ]; then skip "tpm already installed"; return; fi
  log "Installing tmux plugin manager (tpm)"
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" >/dev/null 2>&1 && ok "tpm installed" || warn "tpm clone failed"
}

#------------------------------------------------------------------------------
# main
#------------------------------------------------------------------------------
main() {
  local action=install
  case "${1:-}" in
    ""|install)     ;;
    --uninstall|-u) action=uninstall ;;
    *) err "unknown arg: $1 (use --uninstall to remove symlinks)"; exit 2 ;;
  esac

  log "Dotfiles installer (idempotent) — DOTFILES_DIR=$DOTFILES_DIR, OS=$OS_KIND"
  [ -d "$DOTFILES_DIR" ] || { err "$DOTFILES_DIR not found. Clone your dotfiles there first."; exit 1; }

  if [ "$action" = uninstall ]; then run_unstow; log "Done."; return 0; fi

  ensure_pixi
  ensure_brew_bundle
  ensure_pixi_tools
  ensure_claude_code
  ensure_submodules
  ensure_real_dirs
  backup_existing_targets
  run_stow
  ensure_ssh_include
  ensure_tpm

  log "Done."
  cat <<'EOF'
  Next steps:
    - Open a new shell (or 'source ~/.zshrc') to pick up PATH changes
    - Put machine-local config (anyenv, ANTHROPIC_API_KEY, host paths) in ~/.zshrc.local
    - In tmux, press prefix+I (Ctrl-a I) to install tpm plugins
    - ~/.ssh/config now Includes config.d/*.conf (ControlMaster + ban-safe keepalive)
    - macOS: CLI tools, casks (incl. fuse-t for vdd sshfs), VS Code extensions,
      go/npm globals all come from ./Brewfile — see docs/macos-extras.md for notes
EOF
}

main "$@"
