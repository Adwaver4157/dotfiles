# macOS extras (not managed by install.sh)

`install.sh` installs the cross-platform CLI toolset via **pixi** and symlinks
configs via **stow**. GUI apps, VS Code extensions, and a few heavy/system
packages that pixi doesn't cover are listed here for manual install on macOS.

> These were previously tracked in a `Brewfile`. Kept as a reference so nothing
> is lost after the move to pixi. Install only what you actually need.

## GUI apps (Homebrew casks)

```bash
brew install --cask \
  nikitabobko/tap/aerospace \  # tiling WM (config: aerospace/ stow package)
  jordanbaird-ice \            # menu bar manager
  scoot \                      # keyboard-driven cursor
  utm \                        # VM UI (QEMU)
  ngrok \                      # tunneling
  chromedriver \               # browser automation
  grads \                      # earth science data viz
  font-jetbrains-mono-nerd-font
# Note: kitty is also a cask (brew install --cask kitty); its config is the
# kitty/ stow package.
```

## sshfs on macOS (fuse-t — for `vdd` remote mounts)

macOS has no built-in FUSE. Use **fuse-t** (kext-less, works on Apple Silicon;
no SIP changes, no reboot) rather than macFUSE:

```bash
brew tap macos-fuse-t/cask
brew install fuse-t
brew install fuse-t-sshfs
```

After this, `sshfs` is on PATH and `vdd` auto-mounts remote homes under
`~/mnt/<host>`. On Linux, `install.sh` already adds `sshfs` via pixi. (macFUSE
also works but needs a kernel extension approved in System Settings + reboot.)

`vdd` tuning lives in `~/.zshrc.local`, e.g.:

```bash
export VDD_SKIP_SSHFS_HOSTS="hpc-* abci*"   # don't sshfs-mount ban-prone hosts
vdd_extra_mounts() { case $1 in dev7*) echo /data/$USER ;; esac; }
```

## Heavier CLI / infra via Homebrew (not in the pixi list)

```bash
# Containers & VMs
brew install docker docker-compose buildkit lima qemu kubernetes-cli
# Networking
brew install nmap arp-scan iperf3 cloudflared sshpass
# Crypto / dir services
brew install gnupg openldap
# Documents / media
brew install ghostscript poppler qpdf ffmpeg graphviz typst pandoc
# Japanese NLP
brew install cabocha mecab mecab-ipadic crf++
# Languages / build (if not via pixi/anyenv)
brew install go cmake gradle openjdk guile luarocks anyenv
# GNU userland niceties
brew install coreutils colordiff rsync watch git-lfs mas pulseaudio
```

## Go tools (global)

```bash
go install github.com/go-delve/delve/cmd/dlv@latest
go install github.com/ramya-rao-a/go-outline@latest
go install golang.org/x/tools/cmd/goimports@latest
go install golang.org/x/tools/gopls@latest
go install honnef.co/go/tools/cmd/staticcheck@latest
```

## npm globals

```bash
npm install -g @akari-inc/amath @openai/codex typescript yarn zx
```

## VS Code extensions

Install all at once:

```bash
while read -r ext; do code --install-extension "$ext"; done <<'EOF'
anthropic.claude-code
github.copilot-chat
google.geminicodeassist
openai.chatgpt
ms-python.python
ms-python.vscode-pylance
ms-python.debugpy
ms-python.black-formatter
ms-python.flake8
ms-python.isort
ms-python.vscode-python-envs
njpwerner.autodocstring
ms-toolsai.jupyter
ms-toolsai.jupyter-keymap
ms-toolsai.jupyter-renderers
ms-toolsai.vscode-jupyter-cell-tags
ms-toolsai.vscode-jupyter-slideshow
ms-vscode.cpptools
ms-vscode.cpptools-extension-pack
ms-vscode.cpptools-themes
ms-vscode.cpp-devtools
ms-vscode.cmake-tools
twxs.cmake
ms-vscode.makefile-tools
golang.go
reditorsupport.r
reditorsupport.r-syntax
docker.docker
ms-azuretools.vscode-docker
ms-azuretools.vscode-containers
ms-vscode-remote.remote-containers
ms-vscode-remote.remote-ssh
ms-vscode-remote.remote-ssh-edit
ms-vscode.remote-explorer
github.codespaces
eamodio.gitlens
donjayamanne.githistory
mhutchie.git-graph
ranch-hand-robotics.rde-pack
ranch-hand-robotics.rde-ros-2
ranch-hand-robotics.urdf-editor
smilerobotics.urdf
tomoki1207.pdf
ajshort.msg
ms-ceintl.vscode-language-pack-ja
ms-ceintl.vscode-language-pack-ru
ms-ceintl.vscode-language-pack-zh-hans
ms-ceintl.vscode-language-pack-zh-hant
EOF
```
