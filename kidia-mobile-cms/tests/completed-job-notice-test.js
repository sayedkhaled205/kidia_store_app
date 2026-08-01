"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const script = fs.readFileSync(
  path.resolve(__dirname, "..", "admin", "assets", "cms-shell.js"),
  "utf8",
);

function completedCard(document) {
  const card = document.createElement("section");
  card.className = "kidia-cart-import-state is-complete";
  card.dataset.kidiaBackgroundJob = "abandoned-carts";
  card.dataset.abandonedImportPhase = "complete";
  card.dataset.completeAutoDismiss = "5000";
  card.dataset.completionKey = "1722535200";
  card.hidden = true;
  card.textContent = "Completed — WooCommerce cart history is synced";
  return card;
}

const dom = new JSDOM("<!doctype html><body><div data-kidia-background-job-stack></div></body>", {
  runScripts: "outside-only",
  url: "https://store.test/wp-admin/admin.php?page=kidia-mobile-cms",
});
const timers = [];
dom.window.scrollTo = () => {};
dom.window.setTimeout = (callback, delay) => {
  timers.push({ callback, delay });
  return timers.length;
};
dom.window.clearTimeout = () => {};

const firstCard = completedCard(dom.window.document);
dom.window.document.querySelector("[data-kidia-background-job-stack]").appendChild(firstCard);
dom.window.eval(script);

assert.equal(timers[0].delay, 5000, "The completed import result must remain readable for five seconds.");
assert.equal(firstCard.isConnected, true);
assert.equal(firstCard.hidden, false, "A new completion must be revealed only after its storage key is checked.");

timers.shift().callback();
assert.equal(firstCard.classList.contains("is-leaving"), true, "The completed result must fade before removal.");
assert.match(dom.window.localStorage.getItem("kidiaCompletedBackgroundJobNotices"), /abandoned-carts:1722535200/);
assert.equal(timers[0].delay, 350, "The fade must finish before the card leaves the stack.");

timers.shift().callback();
assert.equal(firstCard.isConnected, false, "The completed import result must be removed after its timeout.");

const repeatedCard = completedCard(dom.window.document);
dom.window.document.querySelector("[data-kidia-background-job-stack]").appendChild(repeatedCard);
dom.window.document.dispatchEvent(new dom.window.CustomEvent("kidia:cms-page-ready"));
assert.equal(repeatedCard.isConnected, false, "The same completed import must not return after CMS navigation or refresh.");
assert.equal(repeatedCard.hidden, true, "A previously seen completion must stay hidden until it is removed.");

const nextCard = completedCard(dom.window.document);
nextCard.dataset.completionKey = "1722535300";
dom.window.document.querySelector("[data-kidia-background-job-stack]").appendChild(nextCard);
dom.window.document.dispatchEvent(new dom.window.CustomEvent("kidia:cms-page-ready"));
assert.equal(nextCard.isConnected, true, "A newly completed import must remain visible long enough to be read.");
assert.equal(nextCard.hidden, false, "A later completion must be revealed after it is identified as new.");
assert.equal(timers[0].delay, 5000);

console.log("Completed background notices auto-dismiss once per finished job.");
