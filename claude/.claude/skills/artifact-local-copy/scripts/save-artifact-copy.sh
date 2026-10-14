#!/usr/bin/env bash
# Save a local, openable copy of an Artifact page.
#
#   save-artifact-copy.sh <source.html> <dest.html> [--url <artifact url>] [--lang ja]
#
# Artifact sources are fragments (the publisher wraps them in <!doctype html>…<body>).
# This adds the same minimal skeleton so the copy opens from file:// with the layout
# the artifact had, and records the artifact URL and date in a leading comment.
# A source that already starts with <!doctype is copied unchanged (comment only).
set -euo pipefail

src="" dest="" url="" lang="ja"
while [ $# -gt 0 ]; do
  case "$1" in
    --url) url="$2"; shift 2 ;;
    --lang) lang="$2"; shift 2 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) if [ -z "$src" ]; then src="$1"; elif [ -z "$dest" ]; then dest="$1"; else echo "too many arguments" >&2; exit 2; fi; shift ;;
  esac
done
[ -n "$src" ] && [ -n "$dest" ] || { echo "usage: $0 <source.html> <dest.html> [--url URL] [--lang ja]" >&2; exit 2; }
[ -f "$src" ] || { echo "no such file: $src" >&2; exit 1; }

mkdir -p "$(dirname "$dest")"
stamp="$(date +%Y-%m-%d)"
comment="<!-- Local copy of a claude.ai Artifact${url:+: $url} (saved $stamp). Edit here and republish with the Artifact tool's url= to keep the link. -->"
tmp="$(mktemp "${dest}.XXXXXX")"

if head -c 512 "$src" | grep -qi '<!doctype'; then
  { echo "$comment"; cat "$src"; } > "$tmp"
else
  {
    cat <<HEAD
<!doctype html>
<html lang="$lang">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
$comment
<style>
  /* same reset the Artifact publisher supplies */
  :root { color-scheme: light; }
  body { margin: 0; font: 14px system-ui, sans-serif; }
  img { max-width: 100%; }
  [hidden] { display: none !important; }
</style>
HEAD
    # <title>, <link>, <style> may sit at the top of the fragment; browsers hoist
    # them from <body> too, so the fragment is placed in <body> unchanged.
    echo "</head>"
    echo "<body>"
    cat "$src"
    echo "</body>"
    echo "</html>"
  } > "$tmp"
fi
mv "$tmp" "$dest"
echo "$dest"
