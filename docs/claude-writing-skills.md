# Japanese writing skills for Claude Code and Codex

Two personal skills are vendored under `claude/.claude/skills/` and installed
into `~/.claude/skills/` by the existing GNU Stow `claude` package. They are
available across local Claude Code projects. The GNU Stow `codex` package
links the same two skill directories into `~/.agents/skills/`, making them
available across local Codex projects as well. The originals remain in the
`claude` package; do not delete it even when only using Codex. This does not
install skills into the claude.ai / Cowork account.

| Skill | Purpose |
| --- | --- |
| `japanese-tech-writing` | Japanese technical prose: argument structure, precision, terminology, and editing. |
| `cognitive-rhythm-writing` | Flow and pacing of explanatory prose. Reads the first skill before working. |

## Install on another machine

After obtaining this dotfiles checkout and GNU Stow:

```sh
cd ~/dotfiles
stow --no-folding --simulate --verbose --target="$HOME" claude codex
stow --no-folding --target="$HOME" claude codex
```

The existing `./install.sh` also installs both packages as part of the full
machine setup. A skill-only update does not require re-running that full setup.
Start a new Claude Code session to check that both slash commands are available.
In Codex, use `/skills` or type `$` to select a skill. If the new skills do not
appear, restart Codex. To install only the Codex links, stow `codex` alone.

## Use

Claude Code:

```text
/japanese-tech-writing docs/draft.md の日本語を推敲してください。
/cognitive-rhythm-writing docs/draft.md の説明の流れと緩急を調整してください。
```

Codex:

```text
$japanese-tech-writing docs/draft.md の日本語を推敲してください。
$cognitive-rhythm-writing docs/draft.md の説明の流れと緩急を調整してください。
```

Upstream names, descriptions, and bodies are preserved without changes. Both
skills retain the default automatic selection behavior when a writing task
matches their description; installing them does not force their rules onto
every conversation. The rhythm skill explicitly reads
`../japanese-tech-writing/SKILL.md`, so keep both sibling directories installed.

These are prose-writing rules. For slides or spoken lecture scripts, state
project-specific requirements explicitly (for example, short headings,
necessary repetition, and preserving code, numbers, and technical conditions).
Do not silently turn the global upstream copy into a lecture-specific variant.

## Provenance and updates

Each skill has an `upstream.json` with its source URL, pinned revision,
retrieval date, SHA-256, and license. k16shikano applies Unlicense to public
gists; the declaration is linked in each metadata file.

To update, fetch the chosen raw revision, review the diff, replace `SKILL.md`,
and update its provenance metadata. Updates are manual, not automatic. Stow
links individual files for Claude (`--no-folding`); the Codex package contains
relative directory symlinks to those same originals. Edits to a source file
are reflected in both `~/.claude/skills/` and `~/.agents/skills/` without
copying it again. Both sibling links are required for the rhythm dependency.

Upstream sources:

- https://gist.github.com/k16shikano/fd287c3133457c4fd8f5601d34aa817d
- https://gist.github.com/k16shikano/eb2929f13ed19c97188393d297be8432
- https://gist.github.com/k16shikano/67625f2a7d96e3bbdfae8d571a936063
- Claude Code skill locations and invocation: https://code.claude.com/docs/en/skills

- Codex skill locations, symlinks, and invocation: https://learn.chatgpt.com/docs/build-skills
