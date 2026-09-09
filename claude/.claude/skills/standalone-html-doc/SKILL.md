---
name: standalone-html-doc
description: >
  Delivers a designed document as a self-contained .html file the user owns,
  plus a Markdown twin, instead of only an Artifact link. Use whenever a page
  has to be pasted into ClickUp/Notion/GitHub, opened offline, handed over as a
  file, kept in a repo, or shared with people who cannot open claude.ai links —
  and whenever the user says html化, 自己完結HTML, 配布用, or "paste this into
  <tool>".
---

# Standalone HTML documents

`Artifact` publishes to a claude.ai URL. That is the right answer when the user
wants a link. It is the wrong answer when they want **a file**, or when the
destination cannot render HTML at all. Decide before writing, not after.

## Pick the delivery first

| Destination | What actually works |
|---|---|
| "send me a link" | `Artifact`. Stop here. |
| ClickUp / Notion / Linear / Jira | **Markdown.** Their APIs take Markdown or plain text; HTML tags arrive as literal text. Checkboxes must be `- [ ]` to become real checkboxes. |
| GitHub PR / issue / repo docs | Markdown. |
| "open it on my machine", offline, a USB stick, an email attachment | Standalone `.html`. |
| Slack | Markdown-ish text, or a link. Never HTML. |
| A teammate who is not in this workspace | Standalone `.html` + a way to reach it (below). |

**Usually produce two artifacts of the same content**: the `.html` for reading
and the Markdown for pasting. They are cheap together and expensive to
retrofit. Do not offer the user a choice they did not ask for — produce both
and say which is which.

## Writing the standalone file

Load `artifact-design` for the visual work — that guidance applies unchanged.
What differs is everything the Artifact runtime would otherwise have supplied.

**Write the whole document.** Artifact content is wrapped in
`<!doctype html><head>…</head><body>` at publish time and gets a CSS reset for
free. A standalone file gets none of that. It needs, in its own source:

```html
<!doctype html>
<html lang="ja">          <!-- the document's real language -->
<head>
<meta charset="utf-8">     <!-- without this, non-ASCII is mojibake from file:// -->
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>…</title>           <!-- becomes the tab and the share preview -->
<style>
  *, *::before, *::after { box-sizing: border-box; }
  body { margin: 0; }
  h1, h2, h3, p, ul, ol, dl, dd, figure { margin: 0; }
  ul, ol { padding: 0; }
  img { max-width: 100%; }
  /* …the page's own styles… */
</style>
</head>
<body>
…
</body>
</html>
```

Omitting the reset is the subtle failure: spacing you tuned against the
Artifact reset collapses or doubles once the browser's defaults apply.

**Self-contained means zero network.** No CDN scripts, no font URLs, no remote
images. Inline the CSS and JS; embed images as `data:` URIs. A file that
silently degrades on a plane is not a deliverable.

**Fonts.** A remote webfont is not an option, and for CJK an inlined one is not
either — a Japanese face is megabytes. Use a system stack and carry the
typography with scale, weight and spacing instead:

```css
--sans: system-ui, -apple-system, "Hiragino Sans", "Noto Sans JP",
        "Yu Gothic UI", Meiryo, sans-serif;
--mono: ui-monospace, SFMono-Regular, Menlo, Consolas, "Noto Sans Mono", monospace;
```

A monospace face for identifiers people must copy exactly — IDs, URLs, ports,
commands — is a real second role, not decoration.

**Both themes, token-level.** Define the palette as custom properties on
`:root`, redefine the tokens under `@media (prefers-color-scheme: dark)`, then
again under `:root[data-theme="dark"]` and `:root[data-theme="light"]`. Style
components through tokens only. Without the `data-theme` blocks the toggle is
inert — the verifier checks exactly this.

**State that survives a reload.** If the page is a checklist, a form, or
anything the reader works through over time, persist it to `localStorage` and
give them a reset control. A checklist that forgets on refresh is worse than
paper.

## Verify before handing it over

Never ship an HTML file you have only read. Run:

```bash
node ~/.claude/skills/standalone-html-doc/scripts/verify-html.mjs <file.html> --out <dir>
```

It fails the build on: unclosed or mismatched tags, a missing document shell,
missing charset/viewport/title, any external resource, sideways scrolling at
390px and 1100px, a dark theme that is never reached, an inert `data-theme`
toggle, and console errors. It writes four screenshots (mobile/desktop ×
light/dark) — **look at them**, then fix and re-run until it exits 0.

## Getting the file to the human

The file is on the machine Claude runs on, which is often not the user's. Say
which of these applies instead of leaving them to work it out:

- **Same machine** — give the absolute path.
- **Over SSH** — give them the `scp` line, ready to paste.
- **Already serving something on that box** — mention they can open it through
  the dev server or an existing tunnel rather than copying it.
- **They want a link after all** — publish the same content with `Artifact`.

## Pasting into a tool that only takes Markdown

Two routes, and they are not equivalent:

1. **Post the Markdown twin through the API.** Structure survives exactly:
   headings, tables, code, and `- [ ]` becoming native checkboxes. Styling does
   not exist. This is the reliable route and the one to default to.
2. **Open the `.html` in a browser, select all, copy, paste into the editor.**
   The editor parses the clipboard's `text/html`, so headings, tables and lists
   survive; CSS does not. Useful when the user specifically wants the structure
   without maintaining a second file — but it is a manual step for them, so
   never present it as the default.

Do not promise that raw HTML tags will render in these tools. They will not.

## Gotchas worth remembering

- ClickUp's document API accepts `text/md` or `text/plain` only. Its comments
  are Markdown too.
- `- [ ]` at the start of a list item is what makes a ClickUp/GitHub checkbox.
  `<input type="checkbox">` is not.
- Bold markers immediately around a Japanese quote (`**「…」**`) can come back
  escaped from some editors' Markdown normalisers; keep emphasis outside the
  brackets when it matters.
- A wide `<table>` or `<pre>` must sit in its own `overflow-x: auto` container,
  or the whole page scrolls sideways on a phone.
- `pkill -f <pattern>` matches the running shell's own command line. Never use
  it to clean up a browser you launched from a command containing that pattern.
