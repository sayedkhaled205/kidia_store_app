"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const script = fs.readFileSync(
  path.resolve(__dirname, "..", "admin", "assets", "cms-shell.js"),
  "utf8",
);

function pointer(window, type, x, y, target) {
  const event = new window.MouseEvent(type, {
    bubbles: true,
    cancelable: true,
    button: 0,
    clientX: x,
    clientY: y,
  });
  (target || window).dispatchEvent(event);
}

function installGeometry(stack) {
  Object.defineProperty(stack, "offsetWidth", { configurable: true, value: 380 });
  Object.defineProperty(stack, "offsetHeight", { configurable: true, value: 300 });
  stack.getBoundingClientRect = () => {
    const left = Number.parseFloat(stack.style.left) || 520;
    const top = Number.parseFloat(stack.style.top) || 360;
    return {
      x: left,
      y: top,
      left,
      top,
      width: 380,
      height: 300,
      right: left + 380,
      bottom: top + 300,
      toJSON() { return this; },
    };
  };
}

const markup = `<!doctype html><body>
  <div data-mobishop-background-job-stack>
    <div data-mobishop-background-job="app-build"><div class="mobishop-ai-progress-card">Build <button type="button">OK</button></div></div>
    <div data-mobishop-background-job="generate-offers"><div class="mobishop-ai-progress-card">Generate Offer</div></div>
    <section class="mobishop-background-job-card" data-mobishop-background-job="abandoned-carts">Generate Abandoned</section>
  </div>
</body>`;

const dom = new JSDOM(markup, {
  runScripts: "outside-only",
  url: "https://store.test/wp-admin/admin.php?page=mobishop",
});
dom.window.scrollTo = () => {};
Object.defineProperty(dom.window, "innerWidth", { configurable: true, value: 1200 });
Object.defineProperty(dom.window, "innerHeight", { configurable: true, value: 900 });
const stack = dom.window.document.querySelector("[data-mobishop-background-job-stack]");
installGeometry(stack);
dom.window.eval(script);

const cards = Array.from(dom.window.document.querySelectorAll("[data-mobishop-background-job]"));
cards.forEach((card, index) => {
  const before = stack.getBoundingClientRect();
  const handle = card.querySelector(".mobishop-ai-progress-card") || card;
  pointer(dom.window, "pointerdown", before.left + 40, before.top + 40, handle);
  pointer(dom.window, "pointermove", before.left - 30 - index, before.top - 20 - index);
  pointer(dom.window, "pointerup", before.left - 30 - index, before.top - 20 - index);
  const after = stack.getBoundingClientRect();
  assert.notEqual(after.left, before.left, `${card.dataset.mobishopBackgroundJob} must drag the shared stack.`);
  assert.notEqual(after.top, before.top, `${card.dataset.mobishopBackgroundJob} must move all cards vertically.`);
  assert.equal(stack.classList.contains("is-dragging"), false, "Dragging state must end after pointerup.");
});

const saved = JSON.parse(dom.window.localStorage.getItem("mobishopBackgroundJobStackPositionV1"));
assert.equal(saved.left, Math.round(stack.getBoundingClientRect().left), "The final horizontal position must persist.");
assert.equal(saved.top, Math.round(stack.getBoundingClientRect().top), "The final vertical position must persist.");

const beforeButton = stack.getBoundingClientRect();
const button = dom.window.document.querySelector("button");
pointer(dom.window, "pointerdown", beforeButton.left + 20, beforeButton.top + 20, button);
pointer(dom.window, "pointermove", 100, 100);
pointer(dom.window, "pointerup", 100, 100);
assert.equal(stack.getBoundingClientRect().left, beforeButton.left, "Buttons inside cards must remain clickable instead of starting a drag.");
assert.equal(stack.getBoundingClientRect().top, beforeButton.top, "Interactive controls must never move the cards.");

const restoredDom = new JSDOM(markup, {
  runScripts: "outside-only",
  url: "https://store.test/wp-admin/admin.php?page=mobishop",
});
restoredDom.window.scrollTo = () => {};
Object.defineProperty(restoredDom.window, "innerWidth", { configurable: true, value: 1200 });
Object.defineProperty(restoredDom.window, "innerHeight", { configurable: true, value: 900 });
const restoredStack = restoredDom.window.document.querySelector("[data-mobishop-background-job-stack]");
installGeometry(restoredStack);
restoredDom.window.localStorage.setItem("mobishopBackgroundJobStackPositionV1", JSON.stringify(saved));
restoredDom.window.eval(script);
assert.equal(restoredStack.style.left, `${saved.left}px`, "The stack must restore its horizontal position after refresh.");
assert.equal(restoredStack.style.top, `${saved.top}px`, "The stack must restore its vertical position after refresh.");

console.log("All three background cards drag one persistent, non-overlapping stack.");
