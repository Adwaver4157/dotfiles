# macOS extras

On macOS the **`Brewfile` at the repo root is the source of truth** for tools:
CLI formulae, GUI casks, fonts, VS Code extensions, and go/npm globals.
`install.sh` runs `brew bundle install --no-upgrade` against it; you can also
run it directly:

```bash
brew bundle install --file=~/dotfiles/Brewfile --no-upgrade   # install missing only
brew bundle check   --file=~/dotfiles/Brewfile                # what's missing?
brew bundle dump    --file=~/dotfiles/Brewfile --force        # re-capture this machine
```

After installing/removing tools, re-dump and commit so the Brewfile keeps
matching the machine.

> History: an earlier revision moved CLI tools to `pixi global`, but this Mac
> was in practice provisioned by Homebrew (pixi global was empty). The Brewfile
> reflects reality; pixi remains the tool source on **Linux** (see
> `install.sh`) and for per-project environments everywhere.

## Homebrew itself

`install.sh` does **not** install Homebrew (its installer wants an interactive
sudo). On a fresh Mac:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## kitty (version-adoption note)

The original Mac runs a directly-downloaded kitty 0.37, older than the current
cask, so `brew install --cask --adopt kitty` refuses to take it over. When you
are ready to upgrade:

```bash
brew install --cask --adopt --force kitty
```

Fresh machines just get kitty from the Brewfile. Its config is the `kitty/`
stow package. (iTerm2 is already cask-adopted.)

## sshfs on macOS (fuse-t — for `vdd` remote mounts)

macOS has no built-in FUSE. The Brewfile installs **fuse-t** + **fuse-t-sshfs**
(kext-less, works on Apple Silicon; no SIP changes, no reboot) rather than
macFUSE. After install, `sshfs` is on PATH and `vdd` auto-mounts remote homes
under `~/mnt/<host>`. On Linux, `install.sh` adds `sshfs` via pixi.

`vdd` tuning lives in `~/.zshrc.local`, e.g.:

```bash
export VDD_SKIP_SSHFS_HOSTS="hpc-* abci*"   # don't sshfs-mount ban-prone hosts
vdd_extra_mounts() { case $1 in dev7*) echo /data/$USER ;; esac; }
```

## VS Code extensions / go tools / npm globals

All captured in the Brewfile (`vscode`, `go`, `npm` entries) and installed by
`brew bundle`. To refresh after adding extensions, re-run the dump command
above.
