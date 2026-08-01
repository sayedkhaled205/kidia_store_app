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
const bundlesPage = readPlugin("admin", "pages", "bundles.php");
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
assert.match(
  bundlesPage,
  /Create a manual bundle[\s\S]*kidia_mobile_save_bundle_recipe[\s\S]*Saved bundles/,
  "The dedicated Bundles page must expose a visible working form and its saved recipes.",
);
assert.match(
  admin,
  /'bundles'=>'kidia-mobile-bundles'[\s\S]*function bundles_page[\s\S]*admin\/pages\/bundles\.php/,
  "Bundles must be a dedicated routable CMS workspace.",
);
assert.match(
  bundleRecipes,
  /'page'\s*=>\s*'kidia-mobile-bundles'[\s\S]*'bundle_saved'\s*=>\s*'1'/,
  "Saving a manual bundle must return to the dedicated Bundles page.",
);
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
    <details class="kidia-ai-playbooks" open><summary>Supported playbooks</summary>
      <button data-ai-playbook-kind="campaign" data-ai-playbook-schemes="fast_offer">Quantity break</button>
      <button data-ai-playbook-kind="merchandising" data-ai-playbook-schemes="fast_rotation">Best sellers</button>
    </details>
    <p data-ai-filter-status></p>
    <button class="is-active" data-ai-workspace-tab="decisions">Decisions</button>
    <button data-ai-workspace-tab="results">Results</button>
    <div data-ai-workspace-panel="decisions">
      <section data-ai-segment-panel="fast">
        <details data-ai-idea-group="offers">
          <article data-ai-decision-kind="campaign" data-ai-decision-scheme="fast_offer"></article>
        </details>
        <details data-ai-idea-group="merchandising">
          <article data-ai-decision-kind="merchandising" data-ai-decision-scheme="fast_rotation"></article>
        </details>
        <div data-ai-playbook-empty hidden></div>
      </section>
      <section data-ai-segment-panel="medium" hidden>
        <details data-ai-idea-group="offers">
          <article data-ai-decision-kind="campaign" data-ai-decision-scheme="medium_rotation"></article>
        </details>
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
  initial.querySelector(".kidia-ai-playbooks").open,
  false,
  "Choosing a playbook must close its dropdown so the filtered data is visible.",
);

const offerGroup = fastPanel.querySelector('[data-ai-idea-group="offers"]');
const merchandisingGroup = fastPanel.querySelector('[data-ai-idea-group="merchandising"]');
offerGroup.open = true;
offerGroup.dispatchEvent(new dom.window.Event("toggle", { bubbles: true }));
merchandisingGroup.open = true;
merchandisingGroup.dispatchEvent(new dom.window.Event("toggle", { bubbles: true }));
assert.equal(offerGroup.open, false, "Opening one recommendation section must close the previous section.");
assert.equal(merchandisingGroup.open, true, "The chosen recommendation section must remain open.");
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
