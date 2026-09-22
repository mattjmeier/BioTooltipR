#!/usr/bin/env node
//
// Browser regression tests for the BioTooltipR Plotly gene hover adapter.
//
// Usage (from the package root):
//   node tests/browser/run-tests.mjs
//
// The suite renders a self-contained fixture (tests/browser/fixture/index.html,
// produced by tests/browser/render-fixture.R), serves it over localhost, and
// drives Chromium through Playwright with MyGene.info mocked. External
// requests are aborted so the suite never depends on the network.
//
// The suite skips cleanly (exit 0) when playwright-core or a Chromium
// executable is not available. It exits 1 when any test fails.

import { createRequire } from "node:module";
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { existsSync, readdirSync } from "node:fs";
import path from "node:path";
import os from "node:os";
import { fileURLToPath, pathToFileURL } from "node:url";

const require = createRequire(import.meta.url);
const here = path.dirname(fileURLToPath(import.meta.url));
const fixtureDir = path.join(here, "fixture");

if (!existsSync(path.join(fixtureDir, "index.html"))) {
  console.error("Fixture missing. Run `Rscript tests/browser/render-fixture.R` first.");
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Locate playwright-core and a Chromium executable
// ---------------------------------------------------------------------------

async function loadPlaywright() {
  try {
    return await import("playwright-core");
  } catch {}
  const candidates = [
    path.join(here, "node_modules", "playwright-core"),
    "/mnt/c/Code/plate-layout-planner/node_modules/playwright-core",
    path.join(os.homedir(), "Code", "plate-layout-planner", "node_modules", "playwright-core"),
  ];
  for (const dir of candidates) {
    if (existsSync(path.join(dir, "package.json"))) {
      try {
        return await import(pathToFileURL(path.join(dir, "index.mjs")).href);
      } catch {
        try {
          return require(path.join(dir, "index.js"));
        } catch {}
      }
    }
  }
  try {
    return require(require.resolve("playwright-core", { paths: [here, process.cwd()] }));
  } catch {}
  return null;
}

function findChromium(pw) {
  for (const name of ["CHROME_PATH", "CHROMIUM_PATH", "PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH"]) {
    if (process.env[name] && existsSync(process.env[name])) return process.env[name];
  }
  try {
    const p = pw.chromium.executablePath();
    if (p && existsSync(p)) return p;
  } catch {}
  const base = path.join(os.homedir(), ".cache", "ms-playwright");
  if (existsSync(base)) {
    const dirs = readdirSync(base)
      .filter((d) => d.startsWith("chromium"))
      .sort()
      .reverse();
    for (const d of dirs) {
      const sub = path.join(base, d);
      const files = [
        "chrome-linux64/chrome",
        "chrome-linux/chrome",
        "chrome-headless-shell-linux64/chrome-headless-shell",
        "chrome-headless-shell-linux/chrome-headless-shell",
      ];
      for (const f of files) {
        const full = path.join(sub, f);
        if (existsSync(full)) return full;
      }
    }
  }
  for (const p of ["/usr/bin/google-chrome", "/usr/bin/google-chrome-stable", "/usr/bin/chromium", "/usr/bin/chromium-browser"]) {
    if (existsSync(p)) return p;
  }
  return null;
}

// ---------------------------------------------------------------------------
// MyGene mock data (covers every gene in the fixture)
// ---------------------------------------------------------------------------

const GENES = {
  TP53: {
    symbol: "TP53", query: "TP53", name: "tumor protein p53",
    summary: "Canned TP53 summary for browser tests.",
    id: "7295", taxid: 9606, species: "hsa", gene_type: "protein_coding",
    location: { genomic_pos: "7:17125801-17150801:1", chr: "7", start: 17125801, end: 17150801, strand: 1 },
  },
  BRCA1: {
    symbol: "BRCA1", query: "BRCA1", name: "BRCA1 DNA repair associated",
    summary: "Canned BRCA1 summary for browser tests.",
    id: "672", taxid: 9606, species: "hsa", gene_type: "protein_coding",
    location: { genomic_pos: "17:43039368-43125193:-1", chr: "17", start: 43039368, end: 43125193, strand: -1 },
  },
  GADD45A: {
    symbol: "GADD45A", query: "GADD45A", name: "growth arrest and DNA damage inducible alpha",
    summary: "Canned GADD45A summary for browser tests.",
    id: "2590", taxid: 9606, species: "hsa", gene_type: "protein_coding",
    location: { genomic_pos: "7:5674774-5699424:1", chr: "7", start: 5674774, end: 5699424, strand: 1 },
  },
  EGFR: {
    symbol: "EGFR", query: "EGFR", name: "epidermal growth factor receptor 2",
    summary: "Canned EGFR summary for browser tests.",
    id: "1956", taxid: 9606, species: "hsa", gene_type: "protein_coding",
    location: { genomic_pos: "7:55019017-55211628:-1", chr: "7", start: 55019017, end: 55211628, strand: -1 },
  },
  MYC: {
    symbol: "MYC", query: "MYC", name: "MYC proto-oncogene, bHLH transcription factor",
    summary: "Canned MYC summary for browser tests.",
    id: "4609", taxid: 9606, species: "hsa", gene_type: "protein_coding",
    location: { genomic_pos: "8:128717867-128738836:-1", chr: "8", start: 128717867, end: 128738836, strand: -1 },
  },
};

function mygeneResponse(request, url) {
  const body = request.postData() || "";
  const params = new URLSearchParams(body);
  const query = (params.get("q") || "").trim().split(/\s+/)[0] || "";
  if (url.pathname.endsWith("/query")) {
    return JSON.stringify(GENES[query] ? [GENES[query]] : []);
  }
  // Detail lookups by id
  const idMatch = url.pathname.match(/^\/v3\/gene\/(\w+)/);
  if (idMatch) {
    const byId = Object.values(GENES).find((g) => g.id === idMatch[1]);
    return JSON.stringify(byId || {});
  }
  return "{}";
}

// ---------------------------------------------------------------------------
// Small test harness
// ---------------------------------------------------------------------------

const results = [];

async function test(name, fn) {
  try {
    await fn();
    results.push({ name, ok: true });
    console.log(`ok   - ${name}`);
  } catch (err) {
    results.push({ name, ok: false, err });
    const firstLine = String((err && err.message) || err).split("\n")[0];
    console.log(`FAIL - ${name}\n       ${firstLine}`);
  }
}

function expectEqual(actual, expected, label) {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) throw new Error(`${label}: expected ${e}, got ${a}`);
}

function expectTrue(value, label) {
  if (!value) throw new Error(`${label}: expected truthy, got ${JSON.stringify(value)}`);
}

// ---------------------------------------------------------------------------
// Page helpers
// ---------------------------------------------------------------------------

// Functions passed to the page (via evaluate/waitForFunction) must be
// self-contained: module-level bindings are not visible inside the page.
const pageEval = {
  rootInfo: () => {
    const root = document.querySelector("[data-gt-tooltip-root]");
    if (!root) return null;
    return {
      inert: root.hasAttribute("inert"),
      visible: root.style.visibility === "visible",
      presentation: root.dataset.presentation || null,
    };
  },
  shownSymbol: () => {
    const el = document.querySelector("[data-gt-tooltip-root] .gene-tooltip-title strong");
    return el ? el.textContent.trim() : null;
  },
  isOpen: () => {
    const root = document.querySelector("[data-gt-tooltip-root]");
    return !!root && !root.hasAttribute("inert") && root.style.visibility === "visible";
  },
  isClosed: () => {
    const root = document.querySelector("[data-gt-tooltip-root]");
    return !root || root.hasAttribute("inert");
  },
};

async function waitPlotReady(page, timeout = 30000) {
  await page.waitForFunction(
    () => {
      const el = document.querySelector(".bt-plotly-gene-hover .html-widget");
      return !!(el && el._fullLayout && typeof el.on === "function");
    },
    { timeout }
  );
}

async function waitForSymbol(page, symbol, timeout = 15000) {
  await page.waitForFunction(
    (sym) => {
      const el = document.querySelector("[data-gt-tooltip-root] .gene-tooltip-title strong");
      return el && el.textContent.trim() === sym;
    },
    symbol,
    { timeout }
  );
}

async function waitForOpen(page, timeout = 15000) {
  await page.waitForFunction(pageEval.isOpen, null, { timeout });
}

async function waitForClosed(page, timeout = 15000) {
  await page.waitForFunction(pageEval.isClosed, null, { timeout });
}

async function pointCenter(page, index) {
  const c = await page.evaluate((idx) => window.__btPointCenter(idx), index);
  if (!c) throw new Error(`marker ${index} not found`);
  return c;
}

async function hoverPoint(page, index) {
  const c = await pointCenter(page, index);
  await page.mouse.move(c.x, c.y, { steps: 4 });
}

async function tapPoint(page, index) {
  const c = await pointCenter(page, index);
  await page.touchscreen.tap(c.x, c.y);
}

async function newPage(browser, { mobile, origin }) {
  const context = await browser.newContext(
    mobile
      ? { viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true }
      : { viewport: { width: 1280, height: 800 } }
  );
  const page = await context.newPage();
  page.on("pageerror", (err) => console.log(`       pageerror: ${err.message}`));
  await page.route("**/*", async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    if (url.origin === origin) return route.continue();
    if (url.hostname === "mygene.info") {
      // Cross-origin fetch: the synthetic response needs CORS headers.
      return route.fulfill({
        status: 200,
        contentType: "application/json",
        headers: { "access-control-allow-origin": "*" },
        body: mygeneResponse(request, url),
      });
    }
    return route.abort();
  });
  await page.goto(`${origin}/index.html`);
  await waitPlotReady(page);
  await page.evaluate(() => window.__btLogEvents());
  return { context, page };
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

const pw = await loadPlaywright();
if (!pw || !pw.chromium) {
  console.log("SKIP: playwright-core not found (install with `npm install` in tests/browser).");
  process.exit(0);
}
const executable = findChromium(pw);
if (!executable) {
  console.log("SKIP: no Chromium executable found (set CHROME_PATH or install a playwright browser).");
  process.exit(0);
}

const server = createServer(async (req, res) => {
  const file = path.join(fixtureDir, req.url === "/" ? "index.html" : req.url.split("?")[0]);
  try {
    const data = await readFile(file);
    const type = file.endsWith(".html")
      ? "text/html"
      : file.endsWith(".js")
        ? "text/javascript"
        : "application/octet-stream";
    res.writeHead(200, { "content-type": type });
    res.end(data);
  } catch {
    res.writeHead(404);
    res.end("not found");
  }
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const origin = `http://127.0.0.1:${server.address().port}`;

let browser;
try {
  browser = await pw.chromium.launch({ executablePath: executable, args: ["--no-sandbox"] });

  // --- Desktop (hover) ----------------------------------------------------

  await test("desktop: hovering a point opens a popover for the correct gene", async () => {
    const { context, page } = await newPage(browser, { mobile: false, origin });
    await hoverPoint(page, 0); // TP53
    await waitForSymbol(page, "TP53");
    const root = await page.evaluate(pageEval.rootInfo);
    expectEqual(root.presentation, "popover", "presentation");
    expectTrue(await page.evaluate(pageEval.isOpen), "popover open");
    await context.close();
  });

  await test("desktop: unhovering closes the popover", async () => {
    const { context, page } = await newPage(browser, { mobile: false, origin });
    await hoverPoint(page, 0); // TP53
    await waitForSymbol(page, "TP53");
    await page.mouse.move(5, 5, { steps: 3 });
    await waitForClosed(page);
    expectTrue(await page.evaluate(pageEval.isClosed), "popover closed");
    await context.close();
  });

  await test("desktop: hovering a second point swaps the gene", async () => {
    const { context, page } = await newPage(browser, { mobile: false, origin });
    await hoverPoint(page, 0); // TP53
    await waitForSymbol(page, "TP53");
    // Move off the card first (the open card covers neighboring points).
    await page.mouse.move(640, 250, { steps: 3 });
    await waitForClosed(page);
    await hoverPoint(page, 1); // BRCA1
    await waitForSymbol(page, "BRCA1");
    expectEqual(await page.evaluate(pageEval.shownSymbol), "BRCA1", "shown symbol");
    await context.close();
  });

  await test("desktop: the card stays open while the pointer moves onto it", async () => {
    const { context, page } = await newPage(browser, { mobile: false, origin });
    await hoverPoint(page, 0); // TP53
    await waitForSymbol(page, "TP53");
    const box = await page.evaluate(() => {
      const el = document.querySelector("[data-gt-tooltip-root] .gt-tooltip-box");
      const b = el.getBoundingClientRect();
      return { x: b.left + b.width / 2, y: b.top + Math.min(50, b.height / 2) };
    });
    // Leave the point (unhover) while the pointer ends up on the card.
    await page.mouse.move(box.x, box.y, { steps: 3 });
    await page.waitForTimeout(500);
    expectTrue(await page.evaluate(pageEval.isOpen), "card still open");
    expectEqual(await page.evaluate(pageEval.shownSymbol), "TP53", "shown symbol");
    await context.close();
  });

  await test("desktop: the card closes when the pointer leaves the card", async () => {
    const { context, page } = await newPage(browser, { mobile: false, origin });
    await hoverPoint(page, 0); // TP53
    await waitForSymbol(page, "TP53");
    const box = await page.evaluate(() => {
      const el = document.querySelector("[data-gt-tooltip-root] .gt-tooltip-box");
      const b = el.getBoundingClientRect();
      return { x: b.left + b.width / 2, y: b.top + Math.min(50, b.height / 2) };
    });
    await page.mouse.move(box.x, box.y, { steps: 3 });
    await page.waitForTimeout(400);
    expectTrue(await page.evaluate(pageEval.isOpen), "card open while pointer is on it");
    // Move the pointer off both the card and the plot (away from any marker).
    await page.mouse.move(10, 750, { steps: 3 });
    await waitForClosed(page);
    expectTrue(await page.evaluate(pageEval.isClosed), "card closed");
    await context.close();
  });
  // --- Mobile (touch) ------------------------------------------------------

  await test("mobile: a touch tap fires plotly_click and opens a drawer", async () => {
    const { context, page } = await newPage(browser, { mobile: true, origin });
    await tapPoint(page, 0); // TP53
    await waitForSymbol(page, "TP53");
    const root = await page.evaluate(pageEval.rootInfo);
    expectEqual(root.presentation, "drawer", "presentation");
    expectTrue(await page.evaluate(pageEval.isOpen), "drawer open");
    const log = await page.evaluate(() => window.__bt.eventLog);
    expectTrue(log.includes("plotly_click"), "plotly_click fired");
    await context.close();
  });

  await test("mobile: the drawer stays open after the tap's DOM click propagates", async () => {
    const { context, page } = await newPage(browser, { mobile: true, origin });
    await tapPoint(page, 0); // TP53
    await waitForSymbol(page, "TP53");
    await page.waitForTimeout(300);
    expectTrue(await page.evaluate(pageEval.isOpen), "drawer still open");
    expectEqual(await page.evaluate(pageEval.shownSymbol), "TP53", "shown symbol");
    await context.close();
  });

  await test("mobile: tapping a second point swaps the selected gene", async () => {
    const { context, page } = await newPage(browser, { mobile: true, origin });
    await tapPoint(page, 0); // TP53
    await waitForSymbol(page, "TP53");
    await tapPoint(page, 1); // BRCA1
    await waitForSymbol(page, "BRCA1");
    const root = await page.evaluate(pageEval.rootInfo);
    expectEqual(root.presentation, "drawer", "presentation");
    expectEqual(await page.evaluate(pageEval.shownSymbol), "BRCA1", "shown symbol");
    await context.close();
  });

  await test("mobile: plotly_unhover does not close a touch-selected drawer", async () => {
    const { context, page } = await newPage(browser, { mobile: true, origin });
    await tapPoint(page, 0); // TP53
    await waitForSymbol(page, "TP53");
    await page.evaluate(() => {
      const el = document.querySelector(".bt-plotly-gene-hover .html-widget");
      el.emit("plotly_unhover", { points: [] });
    });
    await page.waitForTimeout(400);
    expectTrue(await page.evaluate(pageEval.isOpen), "drawer still open");
    expectEqual(await page.evaluate(pageEval.shownSymbol), "TP53", "shown symbol");
    await context.close();
  });

  await test("mobile: tapping outside the drawer dismisses it", async () => {
    const { context, page } = await newPage(browser, { mobile: true, origin });
    await tapPoint(page, 0); // TP53
    await waitForSymbol(page, "TP53");
    await page.touchscreen.tap(10, 12); // page margin, outside plot and drawer
    await waitForClosed(page);
    expectTrue(await page.evaluate(pageEval.isClosed), "drawer closed");
    await context.close();
  });

  await test("mobile: the drawer close button dismisses it", async () => {
    const { context, page } = await newPage(browser, { mobile: true, origin });
    await tapPoint(page, 0); // TP53
    await waitForSymbol(page, "TP53");
    await page.locator(".gt-drawer-handle").click();
    await waitForClosed(page);
    expectTrue(await page.evaluate(pageEval.isClosed), "drawer closed");
    await context.close();
  });

  // --- Re-render / lifecycle -----------------------------------------------

  await test("re-render does not duplicate Plotly or DOM listeners", async () => {
    const { context, page } = await newPage(browser, { mobile: false, origin });
    // Baseline includes the adapter's listeners plus the suite's event-log
    // listeners; after re-renders the counts must be exactly the same.
    const baseline = await page.evaluate(() => window.__btListenerCounts());
    await hoverPoint(page, 0); // TP53: attaches the handle
    await waitForSymbol(page, "TP53");
    await page.mouse.move(5, 5, { steps: 3 });
    await waitForClosed(page);
    await hoverPoint(page, 0); // TP53: attaches the handle
    await waitForSymbol(page, "TP53");
    await page.mouse.move(5, 5, { steps: 3 });
    await waitForClosed(page);

    expectTrue(await page.evaluate(() => window.__btRerender()), "first rerender");
    expectTrue(await page.evaluate(() => window.__btRerender()), "second rerender");

    const after = await page.evaluate(() => window.__btListenerCounts());
    expectEqual(after, baseline, "listener counts stable across re-renders");

    const counters = await page.evaluate(() => ({
      attach: window.__bt.attachCalls,
      destroy: window.__bt.destroyCalls,
    }));
    expectEqual(counters.attach, 1, "attach calls before next use");
    expectEqual(counters.destroy, 1, "destroy calls (first rerender only)");

    // Still fully functional after re-rendering.
    await hoverPoint(page, 1); // BRCA1
    await waitForSymbol(page, "BRCA1");
    const attachAfter = await page.evaluate(() => window.__bt.attachCalls);
    expectEqual(attachAfter, 2, "lazy re-attach after re-render");
    await context.close();
  });

  await test("explicit cleanup destroys the handle and restores the anchor", async () => {
    const { context, page } = await newPage(browser, { mobile: false, origin });
    await hoverPoint(page, 0); // TP53
    await waitForSymbol(page, "TP53");
    const open = await page.evaluate(() => window.__btAnchorAttrs());
    expectEqual(open.tabindex, "-1", "tabindex while attached");
    expectTrue(open.ariaControls !== null, "aria-controls while attached");
    expectEqual(await page.evaluate(() => window.__bt.destroyCalls), 0, "no destroy yet");

    expectTrue(await page.evaluate(() => window.__btCleanup()), "cleanup ran");
    expectEqual(await page.evaluate(() => window.__bt.destroyCalls), 1, "handle destroyed");
    const restored = await page.evaluate(() => window.__btAnchorAttrs());
    expectEqual(restored.tabindex, null, "tabindex restored");
    expectEqual(restored.role, null, "role restored");
    expectEqual(restored.ariaControls, null, "aria-controls restored");
    expectEqual(restored.ariaExpanded, null, "aria-expanded restored");
    await context.close();
  });
} finally {
  if (browser) await browser.close();
  server.close();
}

const failed = results.filter((r) => !r.ok);
console.log(`\n${results.length - failed.length}/${results.length} browser tests passed`);
if (failed.length > 0) {
  process.exit(1);
}
