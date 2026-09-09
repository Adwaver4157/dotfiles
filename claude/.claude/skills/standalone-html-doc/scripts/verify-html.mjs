#!/usr/bin/env node
// Verify a standalone HTML document before handing it to a human.
//
// Catches what is invisible in source but obvious on screen: an unclosed
// <head>, a page that scrolls sideways on a phone, a dark theme that was never
// styled, a theme toggle that does nothing, a script that threw on load.
//
// Usage: node verify-html.mjs <file.html> [--out <dir>]
// Requires: google-chrome or chromium on PATH. No npm dependencies.

import { spawn, spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, join, resolve } from "node:path";

const VOID = new Set(["area", "base", "br", "col", "embed", "hr", "img", "input",
  "link", "meta", "param", "source", "track", "wbr"]);
const RAW_TEXT = new Set(["script", "style"]);

const args = process.argv.slice(2);
const file = args.find((a) => !a.startsWith("--"));
if (!file) {
  console.error("usage: verify-html.mjs <file.html> [--out <dir>]");
  process.exit(2);
}
const outDir = args.includes("--out")
  ? resolve(args[args.indexOf("--out") + 1])
  : join(tmpdir(), "html-verify");
mkdirSync(outDir, { recursive: true });

const path = resolve(file);
const html = readFileSync(path, "utf8");
const problems = [];
const notes = [];

checkStructure();
checkSelfContained();
await checkRendering();

report();
process.exit(problems.length ? 1 : 0);

// ---------------------------------------------------------------- structure

function checkStructure() {
  const stack = [];
  // Skip <script>/<style> bodies so `a < b` inside JS is not read as a tag.
  const re = /<!--[\s\S]*?-->|<(\/?)([a-zA-Z][\w-]*)([^>]*)>/g;
  let m;
  while ((m = re.exec(html))) {
    if (m[0].startsWith("<!--")) continue;
    const [, slash, rawName, attrs] = m;
    const name = rawName.toLowerCase();
    if (VOID.has(name) || attrs.trimEnd().endsWith("/")) continue;
    if (!slash) {
      stack.push(name);
      if (RAW_TEXT.has(name)) {
        const close = html.toLowerCase().indexOf(`</${name}`, re.lastIndex);
        if (close !== -1) { re.lastIndex = close; }
      }
    } else if (stack.at(-1) === name) {
      stack.pop();
    } else {
      problems.push(`</${name}> closed while inside <${stack.at(-1) ?? "nothing"}>`);
    }
  }
  if (stack.length) problems.push(`unclosed at EOF: ${stack.join(" > ")}`);

  const lower = html.toLowerCase();
  const shell = { "<!doctype": "doctype", "<html": "<html>", "<head": "<head>", "<body": "<body>" };
  for (const [needle, label] of Object.entries(shell)) {
    if (!lower.includes(needle)) {
      problems.push(`no ${label} — the Artifact runtime supplies one, a standalone file must not rely on that`);
    }
  }
  if (!/charset/i.test(html)) problems.push("no <meta charset> — non-ASCII text will render as mojibake when opened from disk");
  if (!/name=["']viewport["']/i.test(html)) problems.push("no viewport meta — the page will render zoomed-out on a phone");
  if (!/<title>[^<]+<\/title>/i.test(html)) problems.push("no non-empty <title> — the browser tab and any share preview will be blank");
  if (!/<html[^>]+lang=/i.test(html)) notes.push("no lang attribute on <html> (screen readers and hyphenation use it)");
}

// --------------------------------------------------------- self-containment

function checkSelfContained() {
  const loads = new Set();
  const re = /<(script|link|img|iframe|source|video|audio)\b[^>]*?\b(?:src|href)\s*=\s*["']([^"']+)["']/gi;
  let m;
  while ((m = re.exec(html))) {
    const url = m[2];
    if (/^(https?:)?\/\//i.test(url)) loads.add(`<${m[1].toLowerCase()}> ${url}`);
  }
  if (/@import\s+(url\()?["']?https?:/i.test(html)) loads.add("@import of a remote stylesheet");
  if (loads.size) {
    problems.push(`loads ${loads.size} external resource(s) — inline them, or the file breaks offline and behind a CSP:\n      ` +
      [...loads].slice(0, 6).join("\n      "));
  }
}

// ---------------------------------------------------------------- rendering

async function checkRendering() {
  const chrome = ["google-chrome", "google-chrome-stable", "chromium", "chromium-browser"]
    .find((bin) => spawnSync(bin, ["--version"], { stdio: "ignore" }).status === 0);
  if (!chrome) { notes.push("no chrome on PATH — rendering checks skipped"); return; }

  const port = 9500 + (process.pid % 400);
  const profile = mkdtempSync(join(tmpdir(), "html-verify-"));
  const proc = spawn(chrome, ["--headless=new", "--disable-gpu", "--no-sandbox",
    "--disable-dev-shm-usage", `--remote-debugging-port=${port}`,
    `--user-data-dir=${profile}`, "about:blank"], { stdio: "ignore", detached: true });

  try {
    const cdp = await connect(port);
    const shots = [];

    for (const view of [
      { name: "mobile", width: 390, height: 844, mobile: true },
      { name: "desktop", width: 1100, height: 900, mobile: false },
    ]) {
      for (const theme of ["light", "dark"]) {
        await cdp.send("Emulation.setDeviceMetricsOverride",
          { width: view.width, height: view.height, deviceScaleFactor: 1, mobile: view.mobile });
        await cdp.send("Emulation.setEmulatedMedia",
          { features: [{ name: "prefers-color-scheme", value: theme }] });
        await cdp.send("Page.navigate", { url: `file://${path}` });
        await sleep(1100);

        const s = JSON.parse(await cdp.eval(`JSON.stringify({
          overflow: document.documentElement.scrollWidth - window.innerWidth,
          bg: getComputedStyle(document.body).backgroundColor,
          fg: getComputedStyle(document.body).color,
          height: document.documentElement.scrollHeight })`));
        if (s.overflow > 1) {
          problems.push(`${view.name}/${theme}: body scrolls sideways by ${s.overflow}px — give wide content its own overflow-x:auto container`);
        }
        notes.push(`${view.name}/${theme}: bg ${s.bg} · fg ${s.fg} · ${s.height}px tall`);

        const shot = join(outDir, `${basename(path, ".html")}-${view.name}-${theme}.png`);
        writeFileSync(shot, Buffer.from((await cdp.send("Page.captureScreenshot", { format: "png" })).data, "base64"));
        shots.push(shot);
      }
    }

    // Both themes must be reachable, and the explicit toggle must beat the media query.
    await cdp.send("Emulation.setEmulatedMedia", { features: [{ name: "prefers-color-scheme", value: "light" }] });
    await cdp.send("Page.navigate", { url: `file://${path}` });
    await sleep(900);
    const light = await cdp.eval(`getComputedStyle(document.body).backgroundColor`);
    const forcedDark = await cdp.eval(
      `document.documentElement.setAttribute("data-theme","dark"); getComputedStyle(document.body).backgroundColor`);
    if (light === forcedDark) {
      problems.push(`data-theme="dark" does not change anything — the viewer's theme toggle will be inert`);
    }

    for (const e of cdp.logs.filter((l) => l.level === "error").slice(0, 5)) {
      problems.push(`console error: ${String(e.text).slice(0, 160)}`);
    }
    notes.push(`screenshots in ${outDir}`);
    for (const s of shots) notes.push(`  ${basename(s)}`);
  } finally {
    try { process.kill(-proc.pid); } catch { /* already exited */ }
  }
}

// ------------------------------------------------------------------ helpers

function report() {
  console.log(`file: ${path}`);
  for (const n of notes) console.log("  · " + n);
  if (!problems.length) { console.log("\nOK — no problems found"); return; }
  console.log(`\n${problems.length} problem(s):`);
  for (const p of problems) console.log("  x " + p);
}

function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }

async function connect(port) {
  let list;
  for (let i = 0; i < 40; i++) {
    try { list = await fetch(`http://127.0.0.1:${port}/json/list`).then((r) => r.json()); break; }
    catch { await sleep(250); }
  }
  const target = (list || []).find((t) => t.type === "page");
  if (!target) throw new Error("chrome did not expose a page target");

  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((ok, no) => {
    ws.addEventListener("open", ok, { once: true });
    ws.addEventListener("error", no, { once: true });
  });

  let id = 0;
  const pending = new Map();
  const logs = [];
  ws.addEventListener("message", (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) {
      const { ok, no } = pending.get(msg.id);
      pending.delete(msg.id);
      msg.error ? no(new Error(JSON.stringify(msg.error))) : ok(msg.result);
    } else if (msg.method === "Log.entryAdded") {
      logs.push(msg.params.entry);
    } else if (msg.method === "Runtime.exceptionThrown") {
      logs.push({ level: "error", text: msg.params.exceptionDetails?.exception?.description ?? "uncaught exception" });
    }
  });

  const send = (method, params = {}) => new Promise((ok, no) => {
    const mid = ++id;
    pending.set(mid, { ok, no });
    ws.send(JSON.stringify({ id: mid, method, params }));
  });

  await send("Page.enable");
  await send("Runtime.enable");
  await send("Log.enable");
  return {
    send, logs,
    async eval(expression) {
      const r = await send("Runtime.evaluate", { expression, returnByValue: true, awaitPromise: true });
      return r.result?.value;
    },
  };
}
