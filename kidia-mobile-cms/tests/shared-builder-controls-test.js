"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const pluginRoot = path.resolve(__dirname, "..");
const asset = (name) => fs.readFileSync(path.join(pluginRoot, "admin", "assets", name), "utf8");

function actions(kind) {
  const fixed = kind === "header" || kind === "footer" ? " kidia-fixed-chrome-toggle" : "";
  return `<div class="kidia-card-actions${kind === "home" ? " kidia-builder-block__actions" : ""}" data-actions="${kind}">
    <button class="button kidia-card-action kidia-card-action--primary"><span class="dashicons"></span>Copy</button>
    <button class="button kidia-card-action kidia-card-action--secondary"><span class="dashicons"></span>Paste</button>
    <button class="button kidia-card-action kidia-card-action--expand"><span class="dashicons"></span></button>
    <label class="kidia-builder-switch kidia-builder-switch--card kidia-card-action kidia-card-action--toggle${fixed}">
      <input type="checkbox">
      <span class="kidia-builder-switch__track"></span>
      <span class="kidia-builder-switch__state"></span>
    </label>
  </div>`;
}

const dom = new JSDOM(`<!doctype html><html dir="rtl"><head><style>
${asset("admin-theme.css")}
${asset("cms-shell.css")}
${asset("page-builder.css")}
${asset("chrome-layout.css")}
${asset("category-builder.css")}
${asset("home-builder.css")}
</style></head><body>
  <div class="kidia-page-builder">
    <section class="kidia-page-card kidia-fixed-chrome-card" data-chrome-part="header"><div class="kidia-page-card__header">${actions("header")}</div></section>
    <section class="kidia-page-card kidia-fixed-chrome-card" data-chrome-part="footer"><div class="kidia-page-card__header">${actions("footer")}</div></section>
    <section class="kidia-page-card"><div class="kidia-page-card__header">${actions("page")}</div></section>
    <div class="kidia-shared-builder-toolbar">
      <button class="button">Save Page</button>
      <label class="kidia-page-availability">
        <input type="checkbox">
        <span class="kidia-page-availability__copy"><strong>Page status</strong><small class="kidia-toggle-state"></small></span>
      </label>
    </div>
  </div>
  <div class="kidia-builder-wrap">
    <section class="kidia-builder-block"><div class="kidia-builder-block__header">${actions("home")}</div></section>
  </div>
  <div class="kidia-category-builder">
    <section class="kidia-page-card kidia-category-card"><div class="kidia-page-card__header">${actions("category")}</div></section>
  </div>
</body></html>`, { pretendToBeVisual: true });

const window = dom.window;
const document = window.document;
const pick = (node, properties) => {
  const style = window.getComputedStyle(node);
  return Object.fromEntries(properties.map((property) => [property, style.getPropertyValue(property)]));
};

const actionProperties = ["display", "position", "left", "width", "min-width", "grid-template-columns", "gap"];
const buttonProperties = ["display", "height", "min-height", "padding", "border-radius", "font-size", "line-height"];
const toggleProperties = ["display", "width", "min-width", "height", "min-height", "padding", "overflow"];
const stateProperties = ["width", "min-width", "overflow", "white-space", "text-align"];
const actionSets = [...document.querySelectorAll("[data-actions]")];
const baseline = actionSets.find((node) => node.dataset.actions === "page");

for (const controls of actionSets) {
  if (controls.dataset.actions !== "home") {
    assert.deepEqual(pick(controls, actionProperties), pick(baseline, actionProperties), `${controls.dataset.actions} actions must match the normal page card.`);
  }
  assert.deepEqual(pick(controls.querySelector(".kidia-card-action--primary"), buttonProperties), pick(baseline.querySelector(".kidia-card-action--primary"), buttonProperties), `${controls.dataset.actions} buttons must match the normal page card.`);
  assert.deepEqual(pick(controls.querySelector(".kidia-card-action--toggle"), toggleProperties), pick(baseline.querySelector(".kidia-card-action--toggle"), toggleProperties), `${controls.dataset.actions} On/Off must match the normal page card.`);
  assert.deepEqual(pick(controls.querySelector(".kidia-builder-switch__state"), stateProperties), pick(baseline.querySelector(".kidia-builder-switch__state"), stateProperties), `${controls.dataset.actions} On/Off label must remain unclipped.`);
}

const homeActions = actionSets.find((node) => node.dataset.actions === "home");
assert.deepEqual(
  pick(homeActions, actionProperties),
  {
    display: "grid",
    position: "absolute",
    left: "12px",
    width: "304px",
    "min-width": "304px",
    "grid-template-columns": "74px 74px 40px 104px",
    gap: "4px",
  },
  "Home element actions must stay clear and consistent with the Header and Footer rows."
);

assert.equal(window.getComputedStyle(baseline).width, "304px");
assert.equal(window.getComputedStyle(baseline).gridTemplateColumns, "74px 74px 40px 104px");
assert.equal(window.getComputedStyle(baseline).gap, "4px");
assert.equal(window.getComputedStyle(baseline.querySelector(".kidia-card-action--toggle")).overflow, "visible");

const toolbarButton = document.querySelector(".kidia-shared-builder-toolbar > .button");
const pageStatus = document.querySelector(".kidia-page-availability");
assert.equal(window.getComputedStyle(toolbarButton).height, "34px", "Toolbar buttons must use the shared 34px height.");
assert.equal(window.getComputedStyle(pageStatus).height, "34px", "Page status must match the toolbar button height.");
assert.equal(window.getComputedStyle(pageStatus).width, "138px", "Page status must stay compact after removing the eye.");
assert.equal(window.getComputedStyle(pageStatus).gridTemplateColumns, "38px minmax(82px,1fr)", "Page status must contain only switch and copy columns.");

console.log("Shared controls render consistently, with Home actions contained inside compact element rows.");
