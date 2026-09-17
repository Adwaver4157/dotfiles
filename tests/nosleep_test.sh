#!/usr/bin/env bash
# Tests for bin/.local/bin/nosleep.
#
# nosleep talks to the machine's power management, so every external command it
# touches (pmset, sudo, caffeinate, defaults, osascript) is injected via env and
# replaced here by a stateful fake. Nothing in this file can put the real Mac to
# sleep or keep it awake.
#
#   ./tests/nosleep_test.sh
set -u

SCRIPT="${SCRIPT:-$(cd "$(dirname "$0")/.." && pwd)/bin/.local/bin/nosleep}"
PASS=0
FAIL=0

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }

t_ok()  { PASS=$((PASS + 1)); green "  ok   $1"; }
t_bad() { FAIL=$((FAIL + 1)); red   "  FAIL $1"; [ $# -gt 1 ] && printf "       %s\n" "$2"; }

check_eq() { # label want got
  if [ "$2" = "$3" ]; then t_ok "$1"; else t_bad "$1" "want [$2] got [$3]"; fi
}
check_contains() { # label needle haystack
  case "$3" in *"$2"*) t_ok "$1" ;; *) t_bad "$1" "[$2] not found in: $3" ;; esac
}
check_not_contains() { # label needle haystack
  case "$3" in *"$2"*) t_bad "$1" "[$2] unexpectedly present in: $3" ;; *) t_ok "$1" ;; esac
}

#------------------------------------------------------------------------------
# Fake environment
#------------------------------------------------------------------------------
SANDBOX="$(mktemp -d)"
trap 'pkill -P $$ >/dev/null 2>&1; rm -rf "$SANDBOX"' EXIT

FAKEBIN="$SANDBOX/bin"
mkdir -p "$FAKEBIN"

# pmset: records every call, keeps a persistent disablesleep flag, and answers
# `-g` / `-g ps` from files the test can poke.
cat > "$FAKEBIN/pmset" <<'EOF'
#!/usr/bin/env bash
echo "pmset $*" >> "$FAKE_CALLS"
case "${1:-}" in
  -g)
    case "${2:-}" in
      ps)
        if [ "$(cat "$FAKE_AC" 2>/dev/null || echo 1)" = 1 ]; then
          echo "Now drawing from 'AC Power'"
          echo " -InternalBattery-0 (id=1) $(cat "$FAKE_PCT" 2>/dev/null || echo 91)%; charged; 0:00 remaining present: true"
        else
          echo "Now drawing from 'Battery Power'"
          echo " -InternalBattery-0 (id=1) $(cat "$FAKE_PCT" 2>/dev/null || echo 55)%; discharging; 3:00 remaining present: true"
        fi
        ;;
      *)
        echo "System-wide power settings:"
        echo "Currently in use:"
        [ "$(cat "$FAKE_DISABLED" 2>/dev/null || echo 0)" = 1 ] && echo " SleepDisabled 1"
        echo " sleep                1"
        echo " displaysleep         0"
        ;;
    esac
    ;;
  -a|-b|-c)
    [ "${2:-}" = disablesleep ] && printf '%s' "${3:-}" > "$FAKE_DISABLED"
    ;;
esac
exit 0
EOF

# sudo: transparent, but honours -n so the test can simulate "no cached
# credentials" by setting FAKE_SUDO_N_FAILS=1.
cat > "$FAKEBIN/sudo" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-n" ]; then
  shift
  if [ "${FAKE_SUDO_N_FAILS:-0}" = 1 ]; then
    echo "sudo: a password is required" >&2
    exit 1
  fi
fi
echo "sudo $*" >> "$FAKE_CALLS"
exec "$@"
EOF

# caffeinate: a process that just sits there so pid liveness checks are real.
cat > "$FAKEBIN/caffeinate" <<'EOF'
#!/usr/bin/env bash
echo "caffeinate $*" >> "$FAKE_CALLS"
exec sleep 3600
EOF

# defaults / osascript: silent no-ops (the plist fallback and notifications
# must not reach the real system).
printf '#!/usr/bin/env bash\nexit 1\n'                                  > "$FAKEBIN/defaults"
printf '#!/usr/bin/env bash\necho "osascript $*" >> "$FAKE_CALLS"\n'    > "$FAKEBIN/osascript"
chmod +x "$FAKEBIN"/*

export FAKE_CALLS="$SANDBOX/calls"
export FAKE_DISABLED="$SANDBOX/disabled"
export FAKE_AC="$SANDBOX/ac"
export FAKE_PCT="$SANDBOX/pct"

export NOSLEEP_PMSET="$FAKEBIN/pmset"
export NOSLEEP_SUDO="$FAKEBIN/sudo"
export NOSLEEP_CAFFEINATE="$FAKEBIN/caffeinate"
export NOSLEEP_DEFAULTS="$FAKEBIN/defaults"
export NOSLEEP_OSASCRIPT="$FAKEBIN/osascript"
export NOSLEEP_STATE_DIR="$SANDBOX/state"
export NOSLEEP_ALLOW_NON_DARWIN=1

reset_state() {
  rm -rf "$NOSLEEP_STATE_DIR" "$FAKE_CALLS" "$FAKE_DISABLED" "$FAKE_AC" "$FAKE_PCT"
  unset FAKE_SUDO_N_FAILS
  echo 0 > "$FAKE_DISABLED"
  echo 1 > "$FAKE_AC"
  echo 91 > "$FAKE_PCT"
}
calls()    { cat "$FAKE_CALLS" 2>/dev/null || true; }
disabled() { cat "$FAKE_DISABLED" 2>/dev/null || echo "?"; }
run()      { "$SCRIPT" "$@" 2>&1; }

[ -x "$SCRIPT" ] || { red "nosleep not found or not executable: $SCRIPT"; exit 1; }

#------------------------------------------------------------------------------
echo "== parse_duration =="
# Sourced with NOSLEEP_SOURCE_ONLY so the dispatcher does not run.
# shellcheck disable=SC1090
NOSLEEP_SOURCE_ONLY=1 . "$SCRIPT"

check_eq "bare seconds"      "3600" "$(parse_duration 3600)"
check_eq "90s"               "90"   "$(parse_duration 90s)"
check_eq "45m"               "2700" "$(parse_duration 45m)"
check_eq "2h"                "7200" "$(parse_duration 2h)"
if parse_duration "2.5h" >/dev/null 2>&1; then t_bad "fractional hours rejected"; else t_ok "fractional hours rejected"; fi
if parse_duration "abc"  >/dev/null 2>&1; then t_bad "garbage rejected";          else t_ok "garbage rejected"; fi
if parse_duration ""     >/dev/null 2>&1; then t_bad "empty rejected";            else t_ok "empty rejected"; fi

#------------------------------------------------------------------------------
echo "== status when off =="
reset_state
out=$(run status)
check_contains "reports OFF"             "OFF" "$out"
check_not_contains "does not claim ON"   ": ON" "$out"
check_eq "no pmset write happened"       "" "$(calls | grep 'pmset -a' || true)"

#------------------------------------------------------------------------------
echo "== on =="
reset_state
out=$(run on)
sleep 0.3   # let the detached fake caffeinate write its log line
check_eq       "disablesleep set to 1"   "1" "$(disabled)"
check_contains "pmset called with -a disablesleep 1" "pmset -a disablesleep 1" "$(calls)"
check_contains "caffeinate launched without -d"      "caffeinate -ims"         "$(calls)"
check_eq       "caffeinate pid file written" "yes" "$([ -s "$NOSLEEP_STATE_DIR/caffeinate.pid" ] && echo yes || echo no)"
out=$(run status)
check_contains "status reports ON" "ON" "$out"

#------------------------------------------------------------------------------
echo "== on is idempotent =="
before=$(calls | grep -c 'pmset -a disablesleep 1')
run on >/dev/null
sleep 0.3
after=$(calls | grep -c 'pmset -a disablesleep 1')
check_eq "second on does not re-run pmset" "$before" "$after"
check_eq "still exactly one caffeinate"    "1" "$(calls | grep -c 'caffeinate -ims')"

#------------------------------------------------------------------------------
echo "== off =="
caff_pid=$(cat "$NOSLEEP_STATE_DIR/caffeinate.pid")
out=$(run off)
check_eq       "disablesleep set to 0" "0" "$(disabled)"
check_contains "pmset called with -a disablesleep 0" "pmset -a disablesleep 0" "$(calls)"
sleep 0.3
if kill -0 "$caff_pid" 2>/dev/null; then t_bad "caffeinate killed"; else t_ok "caffeinate killed"; fi
check_eq "caffeinate pid file removed" "gone" "$([ -e "$NOSLEEP_STATE_DIR/caffeinate.pid" ] && echo present || echo gone)"
out=$(run status)
check_contains "status back to OFF" "OFF" "$out"

#------------------------------------------------------------------------------
echo "== toggle =="
reset_state
run toggle >/dev/null
check_eq "toggle from off turns on" "1" "$(disabled)"
run toggle >/dev/null
check_eq "toggle from on turns off" "0" "$(disabled)"

#------------------------------------------------------------------------------
echo "== bad duration changes nothing =="
reset_state
out=$(run on 2.5h); rc=$?
check_eq       "exit code 2"          "2" "$rc"
check_eq       "disablesleep untouched" "0" "$(disabled)"
check_eq       "no pmset write"       "" "$(calls | grep 'pmset -a' || true)"
check_contains "explains the format"  "2h" "$out"

#------------------------------------------------------------------------------
echo "== deadline is recorded =="
reset_state
run on 2h >/dev/null
out=$(run status)
check_contains "status mentions auto-off" "auto-off" "$out"
check_eq "watchdog pid file written" "yes" "$([ -s "$NOSLEEP_STATE_DIR/watchdog.pid" ] && echo yes || echo no)"
run off >/dev/null
check_eq "watchdog pid file removed" "gone" "$([ -e "$NOSLEEP_STATE_DIR/watchdog.pid" ] && echo present || echo gone)"

#------------------------------------------------------------------------------
echo "== battery warning =="
reset_state
echo 0 > "$FAKE_AC"
out=$(run on)
check_contains "warns when on battery" "battery" "$out"
run off >/dev/null

#------------------------------------------------------------------------------
echo "== non-interactive off cannot silently fail =="
reset_state
run on >/dev/null
FAKE_SUDO_N_FAILS=1 out=$(FAKE_SUDO_N_FAILS=1 run off --non-interactive); rc=$?
check_eq       "reports failure"            "1" "$rc"
check_contains "tells the user to run off"  "nosleep off" "$out"
check_eq       "clamshell still disabled"   "1" "$(disabled)"
FAKE_SUDO_N_FAILS=0 run off >/dev/null

#------------------------------------------------------------------------------
echo "== install-sudoers is print-only without --yes =="
reset_state
out=$(run install-sudoers)
check_contains "prints the rule"      "NOPASSWD" "$out"
check_contains "no wildcard in rule"  "pmset -a disablesleep 1" "$out"
check_not_contains "does not install" "/etc/sudoers.d/nosleep written" "$out"

#------------------------------------------------------------------------------
echo
if [ "$FAIL" -eq 0 ]; then green "all $PASS checks passed"; else red "$FAIL failed, $PASS passed"; fi
[ "$FAIL" -eq 0 ]
