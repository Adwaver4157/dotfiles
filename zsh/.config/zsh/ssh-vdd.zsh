# ============================================================================
# SSH connection guard + vdd (virtual desktop docker) — ban-safe edition
# Sourced from ~/.zshrc. Requires rdp-ssh for vdd; sshfs optional.
# Override VDD_* / define vdd_extra_mounts() in ~/.zshrc.local.
# ============================================================================

# ---- ban-safe backoff guard -------------------------------------------------
# Servers with fail2ban ban you for repeated quick connection FAILURES.
# We enforce exponential backoff per host so retries can't hammer them.
_sshguard_dir() { printf '%s' "${XDG_CACHE_HOME:-$HOME/.cache}/sshguard"; }

_ssh_guard() {  # return 1 while still inside the backoff window for $1
  local host=$1 dir; dir=$(_sshguard_dir); mkdir -p "$dir"
  local f=$dir/$host now; now=$(date +%s)
  [[ -f $f ]] || return 0
  local last fails; IFS=: read -r last fails < "$f"
  local wait=$(( fails<=0 ? 0 : (1 << (fails-1)) * 2 )); (( wait > 300 )) && wait=300
  local left=$(( wait - (now - last) ))
  (( left > 0 )) && { print -u2 "sshguard: $host backoff ${left}s (recent fails=$fails)"; return 1; }
  return 0
}
_ssh_fail() { local d; d=$(_sshguard_dir); mkdir -p "$d"; local n=0; [[ -f $d/$1 ]] && IFS=: read -r _ n < "$d/$1"; print "$(date +%s):$((n+1))" > "$d/$1"; }
_ssh_ok()   { rm -f "$(_sshguard_dir)/$1"; }

# Reuse an existing multiplexed master if one is alive (= zero new connections).
_ssh_master_alive() { ssh -O check "$1" 2>/dev/null; }

# ---- vdd: virtual desktop docker (rdp-ssh wrapper) --------------------------
: ${VDD_DEFAULT_SESSION:="desktop-$USER"}
: ${VDD_BASE_PORT:=6090}
: ${VDD_MOUNT_BASE:="$HOME/mnt"}
: ${VDD_SKIP_SSHFS_HOSTS:=""}   # space-separated globs; sshfs not mounted for these
# Optional hook: echo extra remote paths to sshfs-mount for a host.
#   vdd_extra_mounts() { case $1 in dev7*) echo /data/$USER ;; esac; }
command -v vdd_extra_mounts >/dev/null 2>&1 || vdd_extra_mounts() { :; }

_vdd_is_running()  { rdp-ssh -a "$1" list 2>/dev/null | grep -q "^$2"; }
_vdd_port_in_use() { lsof -i ":$1" -sTCP:LISTEN -t >/dev/null 2>&1; }
_vdd_find_free_port() { local p=${1:-$VDD_BASE_PORT}; while _vdd_port_in_use "$p"; do ((p++)); done; print "$p"; }
_vdd_skip_sshfs() { local h=$1 g; for g in ${(z)VDD_SKIP_SSHFS_HOSTS}; do [[ $h == ${~g} ]] && return 0; done; return 1; }

_vdd_sshfs() { sshfs "$1" "$2" -o reconnect,ServerAliveInterval=30,ServerAliveCountMax=3 2>/dev/null; }

_vdd_mount() {  # mount remote home + extra paths (rides the shared ControlMaster)
  local host=$1
  command -v sshfs >/dev/null 2>&1 || return 0
  _vdd_skip_sshfs "$host" && { print "→ sshfs skipped for $host"; return 0; }
  local mp="$VDD_MOUNT_BASE/$host"
  if mount | grep -q " $mp "; then print "→ already mounted $mp"
  else mkdir -p "$mp"; _vdd_sshfs "$host:" "$mp" && print "→ mounted $host: at $mp" || print -u2 "→ sshfs $host failed"; fi
  local rpath flat ld
  for rpath in $(vdd_extra_mounts "$host"); do
    flat=${rpath//\//-}; flat=${flat#-}; ld="$VDD_MOUNT_BASE/${host}-${flat}"
    if mount | grep -q " $ld "; then print "→ already mounted $host:$rpath"
    else mkdir -p "$ld"; _vdd_sshfs "$host:$rpath" "$ld" && print "→ mounted $host:$rpath at $ld" || print -u2 "→ sshfs $host:$rpath failed"; fi
  done
}
_vdd_umount() {
  local host=$1 mp rpath flat ld
  for rpath in $(vdd_extra_mounts "$host"); do
    flat=${rpath//\//-}; flat=${flat#-}; ld="$VDD_MOUNT_BASE/${host}-${flat}"
    mount | grep -q " $ld " && { umount "$ld" 2>/dev/null || diskutil unmount force "$ld" 2>/dev/null; print "→ unmounted $ld"; }
  done
  mp="$VDD_MOUNT_BASE/$host"
  mount | grep -q " $mp " && { umount "$mp" 2>/dev/null || diskutil unmount force "$mp" 2>/dev/null; print "→ unmounted $mp"; }
}

# Smart rdp-ssh wrapper: auto start/connect, auto port-forward, ban-safe.
#   vdd [-n] [-L PORT[:HOST:PORT]]... <ssh-host> [session] [extra rdp-ssh opts...]
#   -n : no port forwarding (for a 2nd terminal to the same session)
#   -L : extra LocalForward on the shared master (repeatable). Shorthand "8080"
#        expands to "8080:localhost:8080". Forwards are cancelled on exit.
vdd() {
  local no_forward=false
  local -a extra_forwards
  while [[ $# -gt 0 ]]; do
    case $1 in
      -n) no_forward=true; shift ;;
      -L) extra_forwards+=("$2"); shift 2 ;;
      *)  break ;;
    esac
  done
  local host=${1:?usage: vdd [-n] [-L PORT[:HOST:PORT]]... <ssh-host> [session] [rdp-ssh-opts...]}
  local session=${2:-$VDD_DEFAULT_SESSION}
  local -a rest
  if (( $# >= 2 )); then shift 2; rest=("$@"); else shift; rest=(); fi

  # Ban-safe gate: reuse master if alive, otherwise respect backoff.
  if ! _ssh_master_alive "$host"; then _ssh_guard "$host" || return 1; fi

  _vdd_mount "$host"

  local action; _vdd_is_running "$host" "$session" && action=connect || action=start

  local -a pf
  if ! $no_forward; then
    if _vdd_port_in_use "$VDD_BASE_PORT"; then
      local fp; fp=$(_vdd_find_free_port); pf=(-p "$fp")
      print "→ ${action} '$session' on $host (port $VDD_BASE_PORT busy → $fp)"
    else
      print "→ ${action} '$session' on $host"
    fi
  else
    print "→ ${action} '$session' on $host (no port forwarding)"
  fi

  # Add any -L port forwards to the existing master (no new TCP).
  local _spec
  for _spec in "${extra_forwards[@]}"; do
    [[ $_spec == *:*:* ]] || _spec="${_spec}:localhost:${_spec}"
    ssh -O forward -L "$_spec" "$host" 2>/dev/null && print "→ forward +L $_spec"
  done

  local t0; t0=$(date +%s)
  rdp-ssh -n "$session" -a "$host" "${pf[@]}" "${rest[@]}" "$action"
  local rc=$? dt=$(( $(date +%s) - t0 ))
  # A quick non-zero exit means we failed to connect → count it for backoff.
  if (( rc != 0 && dt < 15 )); then _ssh_fail "$host"; else _ssh_ok "$host"; fi

  # Cancel any forwards we added; the master itself stays (ControlPersist).
  for _spec in "${extra_forwards[@]}"; do
    [[ $_spec == *:*:* ]] || _spec="${_spec}:localhost:${_spec}"
    ssh -O cancel -L "$_spec" "$host" 2>/dev/null
  done

  _vdd_umount "$host"
  return $rc
}

# Tab-complete hosts from ~/.ssh/config
_vdd() { (( CURRENT == 2 )) && _ssh_hosts; }
compdef _vdd vdd 2>/dev/null
