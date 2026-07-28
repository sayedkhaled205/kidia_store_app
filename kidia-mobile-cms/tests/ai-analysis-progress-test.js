"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const pluginRoot = path.resolve(__dirname, "..");
const shellScript = fs.readFileSync(
  path.join(pluginRoot, "admin", "assets", "cms-shell.js"),
  "utf8",
);

const dom = new JSDOM(
  `<!doctype html><body>
    <div class="kidia-ai-progress-overlay is-docked" data-ai-progress-overlay>
      <div class="kidia-ai-progress-card">
        <div data-ai-progress-ring><strong data-ai-progress-value>0%</strong></div>
        <h2>Store analysis</h2>
        <p data-ai-progress-stage></p>
        <strong data-ai-progress-count></strong>
        <div><i data-ai-progress-bar></i></div>
        <small data-ai-progress-note></small>
        <div><a data-ai-view-results hidden></a><button data-ai-cancel-button>Cancel</button></div>
      </div>
    </div>
  </body>`,
  {
    runScripts: "outside-only",
    url: "https://example.com/wp-admin/admin.php?page=kidia-mobile-ai-insights",
  },
);

const { window } = dom;
window.__KIDIA_AI_PROGRESS_TEST__ = true;
window.kidiaCMSBackground = {};
window.eval(shellScript);

const overlay = window.document.querySelector("[data-ai-progress-overlay]");
const card = overlay.querySelector(".kidia-ai-progress-card");
const value = overlay.querySelector("[data-ai-progress-value]");
const count = overlay.querySelector("[data-ai-progress-count]");
const hook = window.KidiaAiProgressTest;

assert.ok(hook, "The real AI progress renderer must be testable.");
hook.reset(overlay, "job-1");
hook.render(overlay, {
  job_id: "job-1",
  revision: 1,
  processed: 150,
  total: 29080,
  progress: 0.5,
  stage: "Reading paid WooCommerce orders",
});
assert.equal(value.textContent, "0.5%");
assert.match(count.textContent, /^150\s*\/\s*29,080 records completed$/);

hook.render(overlay, {
  job_id: "job-1",
  revision: 0,
  processed: 0,
  total: 29080,
  progress: 0,
  busy: true,
});
assert.equal(
  value.textContent,
  "0.5%",
  "A stale busy response arriving after the first batch must not reset progress to zero.",
);
assert.match(count.textContent, /^150\s*\/\s*29,080 records completed$/);

hook.render(overlay, {
  job_id: "job-1",
  revision: 2,
  processed: 300,
  total: 29080,
  progress: 1,
  stage: "Reading paid WooCommerce orders",
});
assert.equal(value.textContent, "1%");
assert.match(count.textContent, /^300\s*\/\s*29,080 records completed$/);

Object.defineProperties(overlay, {
  offsetWidth: { value: 380 },
  offsetHeight: { value: 180 },
});
overlay.getBoundingClientRect = () => ({
  left: Number.parseFloat(overlay.style.left) || 0,
  top: Number.parseFloat(overlay.style.top) || 0,
  width: 380,
  height: 180,
  right: (Number.parseFloat(overlay.style.left) || 0) + 380,
  bottom: (Number.parseFloat(overlay.style.top) || 0) + 180,
});
Object.defineProperty(window, "innerWidth", { value: 1000, configurable: true });
Object.defineProperty(window, "innerHeight", { value: 700, configurable: true });

card.dispatchEvent(
  new window.MouseEvent("pointerdown", {
    bubbles: true,
    button: 0,
    clientX: 20,
    clientY: 20,
  }),
);
card.dispatchEvent(
  new window.MouseEvent("pointermove", {
    bubbles: true,
    clientX: 340,
    clientY: 260,
  }),
);
card.dispatchEvent(new window.MouseEvent("pointerup", { bubbles: true }));

assert.equal(overlay.style.left, "320px");
assert.equal(overlay.style.top, "240px");
assert.deepEqual(
  JSON.parse(window.localStorage.getItem("kidia_ai_progress_position_v1")),
  { left: 320, top: 240 },
  "The dragged position must persist while the user moves through CMS pages.",
);

console.log("AI progress stays monotonic and the background card is draggable.");
