---
name: codex-fallback
description: Cross-model fallback for the agent-team workflow. When the reviewer raises the SAME (file,issue) finding 3+ times and the Claude implementer hasn't fixed it, escalate that scoped fix to Codex (gpt-5.5) via `codex-fix`. Also run a final `codex-review` cross-model pass at the end of every agent-team run. Use within agent-team runs, or when an implementer is clearly looping on one issue.
---

# Codex fallback (cross-model escalation)

Codex is **not** a Claude subagent type — it is the `codex` CLI, driven via Bash
through two wrappers (in `~/.local/bin`):
- `codex-fix [-C <dir>] "<instruction>"` — Codex EDITS (workspace-write sandbox).
- `codex-review [-C <dir>] [--base <branch>] ["instructions"]` — Codex REVIEWS (read-only).

Both need `codex login` on this machine (`~/.codex/auth.json`). In auto mode the
wrappers are allow-listed (`Bash(codex-fix:*)`, `Bash(codex-review:*)`), so they run
without a prompt.

## 1. Escalation: the 3-strikes rule (during the run)

The reviewer tracks findings per **(file, issue)**. If the reviewer has raised the
*same* finding **3 times** to one implementer and it is still unresolved, the Claude
implementer is looping → escalate to Codex:

1. The reviewer SendMessages the team-lead: `codex escalation: <file> — <issue>`.
2. The lead tells that Claude implementer to **stand down on those file(s)** (no
   concurrent edits) and runs, scoped to the one project + exact files:
   ```
   codex-fix -C <project-dir> "<reviewer finding, verbatim>. Fix it. Touch ONLY <files>."
   ```
3. The lead `git -C <project-dir> diff`s the result and SendMessages the reviewer to
   re-check Codex's edit against PLAN.md.
4. **Cap: one Codex attempt per stuck issue.** If still wrong, STOP and surface to the
   user — do not loop Codex.

## 2. Final cross-model review (every run)

After the smoke-tester passes and **before** team teardown, always run a read-only
Codex pass over the changes:
```
codex-review --base <base-branch>     # or: codex-review   (reviews uncommitted)
```
Summarize Codex's findings for the user. Do **not** auto-apply them; if a finding is
serious, spawn a normal Claude fix task (and only re-escalate via the 3-strikes rule).

## Caveats / failure modes
- **Two model bills** (Claude + Codex gpt-5.5 @ xhigh). Reserve `codex-fix` for genuinely
  stuck spots; the final `codex-review` runs once per team run.
- **Concurrency**: never run `codex-fix` while a Claude implementer edits the same files —
  scope it and pause that implementer first.
- `codex-fix` edits inside the repo (workspace-write); `codex-review` never edits.
- On a remote box, run `codex login` there too (auth is per-machine).
