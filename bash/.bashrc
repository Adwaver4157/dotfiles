# ~/.bashrc (dotfiles, Linux). Machine-local overrides → ~/.bashrc.local
# Interactive shells only.
case $- in *i*) ;; *) return ;; esac

# --- distro essentials ---
[ -f /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion

# --- History ---
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth
shopt -s histappend checkwinsize

# --- PATH (base PATH comes from /etc/profile; we just prepend user dirs) ---
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.pixi/bin:$PATH"
[ -d "$HOME/.cargo/bin" ] && export PATH="$HOME/.cargo/bin:$PATH"

# --- Prompt: starship if present, else a readable colored fallback ---
if command -v starship &>/dev/null; then
  eval "$(starship init bash)"
else
  PS1='\[\e[32m\]\u@\h\[\e[0m\] \[\e[36m\]\w\[\e[0m\] \$ '
fi

# --- Tool init (guarded) ---
command -v zoxide &>/dev/null && eval "$(zoxide init bash)"
command -v fzf    &>/dev/null && eval "$(fzf --bash)" 2>/dev/null
command -v direnv &>/dev/null && eval "$(direnv hook bash)"

# --- Aliases ---
command -v eza &>/dev/null && alias ls='eza'
command -v bat &>/dev/null && alias cat='bat'
alias vi='nvim'
alias vim='nvim'
alias k='kubectl'
alias ..='cd ..'
alias ...='cd ../..'
alias dot='cd ~/dotfiles'

# --- Claude Code: enable agent teams ---
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# --- Functions ---
mkcd() { mkdir -p "$1" && cd "$1"; }

extract() {
  [ -z "$1" ] && { echo "Usage: extract <archive>"; return 1; }
  local a="$1" d="${1%.*}"
  case "$a" in *.tar.gz|*.tar.bz2|*.tar.xz) d="${a%.tar.*}" ;; esac
  mkdir -p "$d"
  case "$a" in
    *.tar.gz|*.tgz)  tar xzf "$a" -C "$d" ;;
    *.tar.bz2|*.tbz) tar xjf "$a" -C "$d" ;;
    *.tar.xz)        tar xJf "$a" -C "$d" ;;
    *.tar)           tar xf  "$a" -C "$d" ;;
    *.zip)           unzip -q "$a" -d "$d" ;;
    *.gz)            gunzip -c "$a" > "$d/${a%.gz}" ;;
    *)               echo "Unknown archive: $a"; rmdir "$d" 2>/dev/null; return 1 ;;
  esac
  echo "Extracted to: $d/"
}

# tmux project switcher (needs fzf + tmux-dev from the bin package)
ts() {
  local dir
  dir=$(find ~/workspace ~/projects ~/work ~/dotfiles -maxdepth 2 -type d 2>/dev/null | fzf) || return
  tmux-dev "$dir"
}

# --- Machine-local (anthropic key, host paths, anything not committed) ---
[ -f ~/.bashrc.local ] && . ~/.bashrc.local
