#!/usr/bin/env bash
# Pattern C: drive Claude Code inside an already-running training container.
# The container is the sandbox; you just exec into it from the host.
#
# Usage:
#   ./claude-exec.sh <container-name-or-id> [claude args...]
#   ./claude-exec.sh my-train-container                 # interactive claude
#   ./claude-exec.sh my-train-container --dangerously-skip-permissions
set -euo pipefail

container="${1:?usage: claude-exec.sh <container> [claude args...]}"
shift || true

if ! docker ps --format '{{.Names}} {{.ID}}' | grep -qw "$container"; then
  echo "error: container '$container' is not running" >&2
  echo "running containers:" >&2
  docker ps --format '  {{.Names}}\t{{.Image}}' >&2
  exit 1
fi

# -w /workspace assumes your code is mounted there; adjust if needed.
exec docker exec -it -w /workspace "$container" claude "$@"
