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
    <form class="mobishop-date-filter">
      <select name="date_preset"><option value="today" selected>Today</option><option value="custom">Custom</option></select>
      <input type="date" name="date_from" disabled>
      <input type="date" name="date_to" disabled>
    </form>
  </body>`,
  {
    runScripts: "outside-only",
    url: "https://example.com/wp-admin/admin.php?page=mobishop&view=store-data",
  },
);

const { window } = dom;
window.mobishopCMSBackground = {};
window.eval(shellScript);

const firstFilter = window.document.querySelector(".mobishop-date-filter");
const firstPreset = firstFilter.querySelector('[name="date_preset"]');
const firstDates = firstFilter.querySelectorAll('input[type="date"]');
assert.equal(firstDates[0].disabled, true);
assert.equal(firstDates[1].disabled, true);

firstPreset.value = "custom";
firstPreset.dispatchEvent(new window.Event("change", { bubbles: true }));
assert.equal(firstDates[0].disabled, false);
assert.equal(firstDates[1].disabled, false);

firstFilter.remove();
const replacement = window.document.createElement("form");
replacement.className = "mobishop-date-filter";
replacement.innerHTML = `
  <select name="date_preset"><option value="all_time">All time</option><option value="custom" selected>Custom</option></select>
  <input type="date" name="date_from" disabled>
  <input type="date" name="date_to" disabled>
`;
window.document.body.appendChild(replacement);
window.document.dispatchEvent(new window.CustomEvent("mobishop:cms-page-ready"));

replacement.querySelectorAll('input[type="date"]').forEach((input) => {
  assert.equal(
    input.disabled,
    false,
    "Custom dates must be enabled after persistent CMS navigation.",
  );
});

console.log("Custom date fields work on initial and dynamically loaded CMS pages.");
