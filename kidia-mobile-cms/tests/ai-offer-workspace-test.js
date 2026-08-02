"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const pluginRoot = path.resolve(__dirname, "..");
const readPlugin = (...parts) =>
  fs.readFileSync(path.join(pluginRoot, ...parts), "utf8");

const workspaceScript = readPlugin(
  "admin",
  "assets",
  "ai-offer-workspace.js",
);
const aiInsights = readPlugin("admin", "pages", "ai-insights.php");
const admin = readPlugin("admin", "class-kidia-mobile-cms-admin.php");
const engine = readPlugin(
  "includes",
  "class-kidia-mobile-ai-offer-engine.php",
);
const bundleRecipes = readPlugin(
  "includes",
  "class-kidia-mobile-bundle-recipes.php",
);
const shellCss = readPlugin("admin", "assets", "cms-shell.css");

assert.match(
  aiInsights,
  /data-ai-segment-tab[\s\S]*data-ai-segment-panel[\s\S]*data-ai-idea-group/,
  "AI Offer Studio must select one product group and organize its ideas under titled groups.",
);
assert.match(
  aiInsights,
  /data-ai-playbook-schemes[\s\S]*data-ai-decision-scheme/,
  "Each playbook must target concrete generated decision schemes.",
);
assert.doesNotMatch(
  aiInsights,
  /Optional manual bundle builder|kidia_mobile_save_bundle_recipe/,
  "The manual bundle builder must not remain inside AI Offer Studio.",
);
assert.doesNotMatch(
  admin,
  /'bundles'\s*=>\s*\$tab/,
  "Bundles must not remain a separate CMS sidebar page.",
);
assert.match(
  bundleRecipes,
  /'page'\s*=>\s*'kidia-mobile-cms'[\s\S]*'view'\s*=>\s*'ai-insights'/,
  "Bundle actions must return to AI Offer Studio.",
);
assert.match(admin, /function bundles_page[\s\S]*view'\s*=>\s*'ai-insights'/, "Legacy Bundle links must redirect into Offers.");
assert.match(engine, /\$lift < 1\.2[\s\S]*Support:[\s\S]*Confidence:[\s\S]*Lift:/, "Bundle decisions must use association strength, not pair count alone.");
assert.match(engine, /Expected incremental revenue[\s\S]*Expected incremental profit/, "Discount decisions must expose forecast revenue and profit when cost exists.");
assert.match(engine, /remove_discount_conflicts/, "The engine must suppress simultaneous discount conflicts on one product.");
assert.match(
  engine,
  /rotation-fast-offer-[\s\S]*'fast_offer'[\s\S]*3\.0[\s\S]*48/,
  "Fast-moving products must include a short controlled executable offer.",
);
assert.match(
  shellCss,
  /kidia-ai-playbook-groups section>div\{[^}]*display:grid[^}]*repeat\(2,minmax\(0,1fr\)\)/,
  "Playbook buttons must use a stable grid instead of random wrapping.",
);
assert.match(
  shellCss,
  /kidia-ai-decision-card>footer \.button\{[^}]*border-color:#2f806e!important[^}]*color:#236b59!important/,
  "Review product buttons must use the Kidia brand palette.",
);

const pageMarkup = (id) => `
  <div class="kidia-ai-page" id="${id}">
    <nav>
      <button class="is-active" data-ai-segment-tab="fast"><span>Fast-moving products</span></button>
      <button data-ai-segment-tab="medium"><span>Medium-moving products</span></button>
    </nav>
    <button data-ai-playbook-kind="campaign" data-ai-playbook-schemes="fast_offer">Quantity break</button>
    <button data-ai-playbook-kind="merchandising" data-ai-playbook-schemes="fast_rotation">Best sellers</button>
    <p data-ai-filter-status></p>
    <button class="is-active" data-ai-workspace-tab="decisions">Decisions</button>
    <button data-ai-workspace-tab="results">Results</button>
    <div data-ai-workspace-panel="decisions">
      <section data-ai-segment-panel="fast">
        <section data-ai-idea-group="offers">
          <article data-ai-decision-kind="campaign" data-ai-decision-scheme="fast_offer"></article>
        </section>
        <section data-ai-idea-group="merchandising">
          <article data-ai-decision-kind="merchandising" data-ai-decision-scheme="fast_rotation"></article>
        </section>
        <div data-ai-playbook-empty hidden></div>
      </section>
      <section data-ai-segment-panel="medium" hidden>
        <section data-ai-idea-group="offers">
          <article data-ai-decision-kind="campaign" data-ai-decision-scheme="medium_rotation"></article>
        </section>
        <div data-ai-playbook-empty hidden></div>
      </section>
    </div>
    <div data-ai-workspace-panel="results" hidden></div>
  </div>
`;

const dom = new JSDOM(`<!doctype html><body>${pageMarkup("initial")}</body>`, {
  runScripts: "outside-only",
  url: "https://example.com/wp-admin/admin.php?page=kidia-mobile-ai-insights",
});
dom.window.eval(workspaceScript);
dom.window.document.dispatchEvent(new dom.window.Event("DOMContentLoaded"));

const initial = dom.window.document.querySelector("#initial");
const fastPanel = initial.querySelector('[data-ai-segment-panel="fast"]');
const mediumPanel = initial.querySelector('[data-ai-segment-panel="medium"]');
assert.equal(fastPanel.hidden, false, "Fast must be the one initial visible group.");
assert.equal(mediumPanel.hidden, true, "Other product groups must not stack below Fast.");

initial
  .querySelector('[data-ai-segment-tab="medium"]')
  .dispatchEvent(new dom.window.MouseEvent("click", { bubbles: true }));
assert.equal(fastPanel.hidden, true, "Selecting Medium must hide Fast.");
assert.equal(mediumPanel.hidden, false, "Selecting Medium must show only Medium.");

const quantityBreak = initial.querySelector(
  '[data-ai-playbook-schemes="fast_offer"]',
);
quantityBreak.dispatchEvent(
  new dom.window.MouseEvent("click", { bubbles: true }),
);
assert.equal(
  fastPanel.hidden,
  false,
  "A playbook must switch to the first product group containing a real matching idea.",
);
assert.equal(
  mediumPanel.hidden,
  true,
  "A playbook must not leave an unrelated product group stacked beside its results.",
);
assert.equal(
  quantityBreak.getAttribute("aria-pressed"),
  "true",
  "A clicked playbook must expose a real active state.",
);
assert.equal(
  fastPanel.querySelector('[data-ai-decision-scheme="fast_offer"]').hidden,
  false,
  "The selected playbook must retain matching offer decisions.",
);
assert.equal(
  fastPanel.querySelector('[data-ai-decision-scheme="fast_rotation"]').hidden,
  true,
  "The selected playbook must hide unrelated ideas.",
);
assert.equal(
  fastPanel.querySelector('[data-ai-idea-group="merchandising"]').hidden,
  true,
  "An idea heading with no visible match must also hide.",
);

quantityBreak.dispatchEvent(
  new dom.window.MouseEvent("click", { bubbles: true }),
);
assert.equal(
  fastPanel.querySelector('[data-ai-decision-scheme="fast_rotation"]').hidden,
  false,
  "Clicking the active playbook again must clear the filter.",
);

initial
  .querySelector('[data-ai-workspace-tab="results"]')
  .dispatchEvent(new dom.window.MouseEvent("click", { bubbles: true }));
assert.equal(
  initial.querySelector('[data-ai-workspace-panel="decisions"]').hidden,
  true,
  "Workspace tabs must switch away from generated decisions.",
);
assert.equal(
  initial.querySelector('[data-ai-workspace-panel="results"]').hidden,
  false,
  "Workspace tabs must reveal Actions & Results.",
);

initial.remove();
dom.window.document.body.insertAdjacentHTML(
  "beforeend",
  pageMarkup("fragment"),
);
dom.window.document.dispatchEvent(
  new dom.window.CustomEvent("kidia:cms-page-ready"),
);
const fragment = dom.window.document.querySelector("#fragment");
fragment
  .querySelector('[data-ai-segment-tab="medium"]')
  .dispatchEvent(new dom.window.MouseEvent("click", { bubbles: true }));
assert.equal(
  fragment.querySelector('[data-ai-segment-panel="medium"]').hidden,
  false,
  "Controls must be rebound after the persistent CMS loads AI Offer as a fragment.",
);

console.log("AI Offer workspace interaction tests passed.");
