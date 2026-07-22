"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const { JSDOM } = require("jsdom");

const assets = path.resolve(__dirname, "..", "admin", "assets");

function runBridge(asset, body) {
  const dom = new JSDOM(`<!doctype html><body>${body}</body>`, {
    runScripts: "outside-only",
    url: "https://store.example/wp-admin/admin.php",
  });
  const { window } = dom;
  const frame = window.document.getElementById("kidia-flutter-preview");
  const messages = [];
  frame.contentWindow.postMessage = (message, origin) => messages.push({ message: JSON.parse(message), origin });
  window.setTimeout = () => 1;
  window.eval(fs.readFileSync(path.join(assets, asset), "utf8"));
  return messages;
}

test("generic Flutter preview sends state immediately when cached iframe load was missed", () => {
  const messages = runBridge("flutter-preview-bridge.js", `
    <div class="kidia-page-builder" data-page="catalog">
      <form class="kidia-page-editor"><input name="layout[header][enabled]" value="1"></form>
      <div id="kidia-page-elements"><div class="kidia-page-card" data-element="product_grid"></div></div>
    </div>
    <iframe id="kidia-flutter-preview" src="https://store.example/preview/index.html"></iframe>`);
  assert.equal(messages.length, 1);
  assert.equal(messages[0].message.page, "catalog");
  assert.equal(messages[0].message.layout.header.enabled, "1");
  assert.equal(messages[0].message.layout.elements[0].id, "product_grid");
  assert.equal(messages[0].origin, "https://store.example");
});

test("Category Flutter preview sends current fields immediately", () => {
  const messages = runBridge("flutter-category-preview-bridge.js", `
    <div class="kidia-category-builder"><form>
      <input name="category_general[grid_columns]" type="number" value="3">
      <input name="category_general[show_arrow]" type="checkbox" checked>
    </form></div>
    <iframe id="kidia-flutter-preview" src="https://store.example/preview/index.html"></iframe>`);
  assert.equal(messages.length, 1);
  assert.equal(messages[0].message.category.grid_columns, 3);
  assert.equal(messages[0].message.category.show_arrow, true);
});

test("Home Flutter preview sends an initial frame without waiting for iframe load", () => {
  const messages = runBridge("flutter-home-preview-bridge.js", `
    <div class="kidia-builder-wrap"></div>
    <form id="kidia-home-builder-form"><input name="layout[header][enabled]" value="1"></form>
    <iframe id="kidia-flutter-preview" src="https://store.example/preview/index.html"></iframe>`);
  assert.equal(messages.length, 1);
  assert.equal(messages[0].message.page, "home");
  assert.equal(messages[0].message.layout.header.enabled, "1");
  assert.deepEqual(messages[0].message.home.blocks, []);
});
