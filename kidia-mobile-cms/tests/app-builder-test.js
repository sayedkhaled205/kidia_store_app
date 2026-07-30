"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const script = fs.readFileSync(path.resolve(__dirname, "..", "admin", "assets", "app-builder.js"), "utf8");

function markup(status, autoDownload = false) {
  return `<!doctype html><body>
    <div data-kidia-app-build data-status="${status}" data-can-build="1" data-auto-download="${autoDownload ? "1" : "0"}">
      <p data-build-message>Queued</p>
      <div data-build-progress><span data-build-progress-value aria-valuenow="0"></span></div>
      <div data-build-modal hidden>
        <div class="kidia-app-build__modal-card">
          <div data-build-progress-ring><strong data-build-progress-label>0%</strong></div>
          <strong data-build-stage>Waiting</strong>
        <p data-build-message>Queued</p>
          <button type="button" data-build-background>Continue in background</button>
        </div>
      </div>
      <div class="kidia-app-build__actions">
        <form method="post" data-build-form>
          <input type="hidden" name="action" value="kidia_mobile_build_app" data-build-form-action>
          <input type="hidden" name="kidia_mobile_build_nonce" value="build-nonce">
          <input type="hidden" name="kidia_mobile_download_nonce" value="download-nonce">
          <button type="submit" data-build-action>
            <span class="dashicons dashicons-smartphone" data-build-action-icon></span>
            <span data-build-action-label>Build & Download Your App</span>
          </button>
        </form>
        <button type="button" data-build-cancel ${["queued", "building"].includes(status) ? "" : "hidden"}>Cancel Build</button>
      </div>
    </div>
  </body>`;
}

function builderConfig() {
  return {
    ajaxUrl: "https://store.test/wp-admin/admin-ajax.php",
    nonce: "status-nonce",
    cancelNonce: "cancel-nonce",
    labels: {
      starting: "Starting APK build…",
      building: "Building your APK…",
      ready: "Your APK is ready to install.",
      buildDownload: "Build & Download Your App",
      download: "Download APK",
      cancelled: "Build cancelled.",
      cancelFailed: "The build could not be cancelled.",
      timeout: "The APK build request took too long. Please try again."
    }
  };
}

async function flush() {
  await new Promise((resolve) => setImmediate(resolve));
  await new Promise((resolve) => setImmediate(resolve));
}

async function testReadyBuildDownloadsFromTheSameControl() {
  const dom = new JSDOM(markup("queued", true), {
    runScripts: "outside-only",
    url: "https://store.test/wp-admin/admin.php"
  });
  const root = dom.window.document.querySelector("[data-kidia-app-build]");
  const form = root.querySelector("[data-build-form]");
  let requestBody = "";
  let downloadSubmits = 0;

  dom.window.kidiaAppBuilder = builderConfig();
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
  form.addEventListener("submit", (event) => {
    if (form.querySelector("[data-build-form-action]").value === "kidia_mobile_download_apk") {
      downloadSubmits += 1;
      event.preventDefault();
    }
  });

  dom.window.eval(script);
  await flush();

  const button = root.querySelector("[data-build-action]");
  assert.match(requestBody, /action=kidia_mobile_app_build_status/, "An active build must poll the protected status action.");
  assert.equal(root.dataset.status, "ready", "The UI must move to the ready state.");
  assert.equal(root.querySelector("[data-build-message]").textContent, "Your APK is ready to install.");
  assert.equal(root.querySelector("[data-build-progress-value]").getAttribute("aria-valuenow"), "100");
  assert.equal(root.querySelectorAll("[data-build-action]").length, 1, "Overview must expose one build/download control.");
  assert.equal(form.querySelector("[data-build-form-action]").value, "kidia_mobile_download_apk");
  assert.equal(button.querySelector("[data-build-action-label]").textContent, "Download APK");
  assert.equal(button.disabled, false);
  assert.equal(downloadSubmits, 1, "A build started by this page must download automatically when the APK becomes ready.");
}

async function testIdleControlStartsBuildAndShowsProgress() {
  const dom = new JSDOM(markup("idle"), {
    runScripts: "outside-only",
    url: "https://store.test/wp-admin/admin.php"
  });
  const root = dom.window.document.querySelector("[data-kidia-app-build]");
  let requestBody = "";

  dom.window.kidiaAppBuilder = builderConfig();
  dom.window.fetch = async (_url, options) => {
    requestBody = options.body;
    return {
      ok: true,
      json: async () => ({
        success: true,
        data: {
          status: "building",
          progress: 15,
          message: "Preparing Android build.",
          downloadReady: false
        }
      })
    };
  };
  dom.window.setTimeout = () => 0;
  dom.window.eval(script);

  root.querySelector("[data-build-action]").click();
  await flush();

  const button = root.querySelector("[data-build-action]");
  assert.match(requestBody, /action=kidia_mobile_app_build_start/, "The single control must start the build through AJAX without reloading Overview.");
  assert.match(requestBody, /nonce=build-nonce/);
  assert.equal(root.dataset.status, "building");
  assert.equal(button.disabled, false, "The active card remains clickable so the merchant can reopen progress.");
  assert.equal(button.hidden, false, "The build card must remain present while progress is shown separately.");
  assert.equal(button.classList.contains("is-loading"), true, "The same button must show its loading state during a long build.");
  assert.equal(button.getAttribute("aria-busy"), "true");
  assert.equal(button.querySelector("[data-build-action-label]").textContent, "Building your APK… 15%");
  assert.equal(root.querySelector("[data-build-progress]").hidden, false);
  assert.equal(root.querySelector("[data-build-modal]").hidden, false, "Clicking the full card must open the build progress dialog.");
  assert.equal(root.querySelector("[data-build-cancel]").hidden, false, "Cancel must appear while the build is active.");
}

async function testFailedBuildReturnsTheSameControlToRetry() {
  const dom = new JSDOM(markup("idle"), {
    runScripts: "outside-only",
    url: "https://store.test/wp-admin/admin.php"
  });
  const root = dom.window.document.querySelector("[data-kidia-app-build]");

  dom.window.kidiaAppBuilder = builderConfig();
  dom.window.fetch = async () => ({
    ok: false,
    json: async () => ({
      success: false,
      data: { message: "The WooMobile build service rejected the request." }
    })
  });
  dom.window.setTimeout = () => 0;
  dom.window.eval(script);

  root.querySelector("[data-build-action]").click();
  await flush();

  const button = root.querySelector("[data-build-action]");
  assert.equal(root.dataset.status, "failed");
  assert.equal(root.querySelector("[data-build-message]").textContent, "The WooMobile build service rejected the request.");
  assert.equal(root.querySelector("[data-build-form-action]").value, "kidia_mobile_build_app");
  assert.equal(root.querySelector("[data-build-modal]").hidden, false, "A failed build card must remain visible until Cancel.");
  assert.equal(button.disabled, false);
  assert.equal(button.classList.contains("is-loading"), false);
  assert.equal(button.querySelector("[data-build-action-label]").textContent, "Build & Download Your App");
  assert.equal(root.querySelectorAll("[data-build-action]").length, 1, "Failure must not reveal a second download button.");
}

async function testHungStartRequestReturnsToRetry() {
  const dom = new JSDOM(markup("idle"), {
    runScripts: "outside-only",
    url: "https://store.test/wp-admin/admin.php"
  });
  const root = dom.window.document.querySelector("[data-kidia-app-build]");

  dom.window.kidiaAppBuilder = {
    ...builderConfig(),
    requestTimeout: 100
  };
  dom.window.fetch = (_url, options) => new Promise((_resolve, reject) => {
    options.signal.addEventListener("abort", () => {
      const error = new Error("aborted");
      error.name = "AbortError";
      reject(error);
    });
  });
  dom.window.eval(script);

  root.querySelector("[data-build-action]").click();
  await new Promise((resolve) => setTimeout(resolve, 150));
  await flush();

  const button = root.querySelector("[data-build-action]");
  assert.equal(root.dataset.status, "failed", "A hung start request must not leave Overview on Starting forever.");
  assert.equal(root.querySelector("[data-build-message]").textContent, "The APK build request took too long. Please try again.");
  assert.equal(button.disabled, false);
  assert.equal(button.querySelector("[data-build-action-label]").textContent, "Build & Download Your App");
}

async function testActiveBuildCanBeCancelled() {
  const dom = new JSDOM(markup("building"), {
    runScripts: "outside-only",
    url: "https://store.test/wp-admin/admin.php"
  });
  const root = dom.window.document.querySelector("[data-kidia-app-build]");
  const requests = [];

  dom.window.kidiaAppBuilder = builderConfig();
  dom.window.fetch = async (_url, options) => {
    requests.push(options.body.toString());
    const cancelling = options.body.toString().includes("kidia_mobile_app_build_cancel");
    return {
      ok: true,
      json: async () => ({
        success: true,
        data: cancelling
          ? { status: "idle", progress: 0, message: "", downloadReady: false, dismissed: true }
          : { status: "building", progress: 20, message: "Building.", downloadReady: false }
      })
    };
  };
  dom.window.setTimeout = () => 0;
  dom.window.eval(script);

  const modal = root.querySelector("[data-build-modal]");
  assert.equal(modal.hidden, false, "An existing build card must be restored after page load.");
  root.querySelector("[data-build-action]").click();
  assert.equal(modal.hidden, false, "Clicking the active build card must explicitly open progress.");

  const cancelButton = root.querySelector("[data-build-cancel]");
  assert.equal(cancelButton.hidden, false, "Cancel must be visible when the page loads with an active build.");
  cancelButton.click();
  await flush();

  assert.equal(requests.some((body) => body.includes("action=kidia_mobile_app_build_cancel")), true);
  assert.equal(requests.some((body) => body.includes("nonce=cancel-nonce")), true);
  assert.equal(root.dataset.status, "idle");
  assert.equal(modal.hidden, true);
  assert.equal(cancelButton.hidden, true);
  assert.equal(root.querySelector("[data-build-action-label]").textContent, "Build & Download Your App");
  assert.equal(root.querySelector("[data-build-action]").disabled, false);
  assert.equal(root.querySelector("[data-build-action]").hidden, false);
}

(async function () {
  await testReadyBuildDownloadsFromTheSameControl();
  await testIdleControlStartsBuildAndShowsProgress();
  await testFailedBuildReturnsTheSameControlToRetry();
  await testHungStartRequestReturnsToRetry();
  await testActiveBuildCanBeCancelled();
  console.log("APK single build-and-download control tests passed.");
})();
