"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const script = fs.readFileSync(path.resolve(__dirname, "..", "admin", "assets", "app-builder.js"), "utf8");

(async function () {
  const dom = new JSDOM(`<!doctype html><body>
    <div data-kidia-app-build data-status="queued">
      <p data-build-message>Queued</p>
      <div data-build-progress><span data-build-progress-value aria-valuenow="0"></span></div>
      <a data-build-download hidden>Download APK</a>
    </div>
  </body>`, { runScripts: "outside-only", url: "https://store.test/wp-admin/admin.php" });

  let requestBody = "";
  dom.window.kidiaAppBuilder = {
    ajaxUrl: "https://store.test/wp-admin/admin-ajax.php",
    nonce: "test-nonce",
    downloadUrl: "https://store.test/wp-admin/admin-post.php?action=kidia_mobile_download_apk&nonce=test",
    labels: { ready: "Your APK is ready to install." }
  };
  dom.window.fetch = async (_url, options) => {
    requestBody = options.body;
    return {
      ok: true,
      json: async () => ({
        success: true,
        data: {
          status: "ready",
          progress: 100,
          message: "Your APK is ready to install.",
          downloadReady: true
        }
      })
    };
  };
  dom.window.setTimeout = () => 0;
  dom.window.eval(script);
  await new Promise((resolve) => setImmediate(resolve));
  await new Promise((resolve) => setImmediate(resolve));

  const root = dom.window.document.querySelector("[data-kidia-app-build]");
  const download = root.querySelector("[data-build-download]");
  assert.match(requestBody, /action=kidia_mobile_app_build_status/, "The page must poll the protected build-status action.");
  assert.equal(root.dataset.status, "ready", "The UI must move to the ready state.");
  assert.equal(root.querySelector("[data-build-message]").textContent, "Your APK is ready to install.");
  assert.equal(root.querySelector("[data-build-progress-value]").getAttribute("aria-valuenow"), "100");
  assert.equal(download.hidden, false, "Download APK must appear only after the service reports a ready artifact.");
  assert.equal(download.href, dom.window.kidiaAppBuilder.downloadUrl);

  console.log("APK build status UI test passed.");
})();
