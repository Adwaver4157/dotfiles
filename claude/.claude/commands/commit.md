---
description: Generate a concise one-line Conventional Commit from staged changes and commit (no push).
---

Create a commit from the currently **staged** changes.

Steps:
1. Run `git diff --cached`. If nothing is staged, stop and tell the user to stage
   files first — do NOT run `git add -A` / `git add .` yourself.
2. Infer the primary intent of the change.
3. Commit with a **single-line** Conventional Commit message:
   `type(scope): description`
   - types: feat, fix, perf, refactor, chore, docs, test, style
   - one line only; add a short body ONLY if the change is genuinely non-obvious
   - scope is optional and conceptual (never a filename)
   - description: English, imperative, concise
4. Do NOT add a `Co-Authored-By` trailer or any "Generated with Claude Code" footer.
5. Do NOT push.

If the user passed text after `/commit`, treat it as the intent to ground the message.
