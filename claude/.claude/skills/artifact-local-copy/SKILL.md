---
name: artifact-local-copy
description: >
  Whenever an Artifact (an HTML page published with the Artifact tool) is
  created or updated, also save the same HTML as a file the user owns, next to
  the project it belongs to. Use on every Artifact publish without being asked,
  and when the user says ローカルにも保存, html も残して, or asks where the
  artifact's source is.
---

# Keep a local copy of every Artifact

An Artifact is an HTML file hosted on claude.ai. The hosted page can be lost
with the account, is hard to diff, and cannot be grepped. The rule here is
simple: **the file that was published is also saved on disk, every time.**

## Where the copy goes

1. Inside the git repository the content is about, under `docs/artifacts/<slug>.html`.
   A page documenting `~/household/hsr-vla-devloop` goes to
   `~/household/hsr-vla-devloop/docs/artifacts/`.
2. If no single repository owns it (a cross-repo design note, a comparison),
   use `<workspace>/docs/artifacts/<slug>.html`, where `<workspace>` is the
   session's working directory (for `~/household` that is `~/household/docs/artifacts/`).
3. Never leave the only copy in the scratchpad or `/tmp`.

`<slug>` is the artifact's file basename (kebab-case, ASCII). Republishing the
same artifact overwrites the same file; a new artifact gets a new slug.

## How

The Artifact tool wraps the source in `<!doctype html>…<body>` at publish time,
so the source on disk is a fragment that opens badly from `file://`. Run the
helper after each publish; it adds the same skeleton and a leading comment
with the artifact URL and date:

```bash
~/.claude/skills/artifact-local-copy/scripts/save-artifact-copy.sh \
  <scratchpad>/<slug>.html <repo>/docs/artifacts/<slug>.html --url <artifact url>
```

A source that already is a full document is copied unchanged apart from the
comment. The copy keeps its CDN script and Google Fonts links: it is a
faithful copy of the page, not an offline deliverable. When the user needs a
file that works with no network, use `standalone-html-doc` instead (or as well).

## Reporting and git

- Name the saved path in the final message, in one line next to the artifact link.
- If the destination is a tracked repository and the task already includes
  committing, include the file in that commit (`docs: add <slug> artifact copy`).
  Otherwise leave it uncommitted and say so; the user decides.
- To edit later, edit the local copy and republish with the Artifact tool's
  `url=` so the link stays the same. The leading comment holds the URL.

## Failure modes

- Forgetting the skeleton: the fragment renders, but with browser defaults
  instead of the publisher's reset, so spacing differs from the artifact.
- Saving under the scratchpad: it is per-session and is cleaned up.
- Two artifacts with the same slug in one repo: the second silently overwrites
  the first. Pick a distinct basename before publishing.
