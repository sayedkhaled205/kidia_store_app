"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const script = fs.readFileSync(path.resolve(__dirname, "..", "admin", "assets", "app-builder.js"), "utf8");

function markup(status, autoDownload = false) {
  return `<!doctype html><body>
    <div data-kidia-app-build data-status="${status}" data-can-build="1" data-auto-download="${autoDownload ? "1" : "0"}" data-completed-at="0">
      <p data-build-message>Queued</p>
      <div data-build-progress><span data-build-progress-value aria-valuenow="0"></span></div>
      <div data-build-modal hidden>
        <div class="kidia-app-build__modal-card">
          <div data-build-progress-ring><strong data-build-progress-label>0%</strong></div>
          <strong data-build-stage>Waiting</strong>
        <p data-build-message>Queued</p>
          <h2 data-build-title>Building your app</h2>
        </div>
      </div>
      <div class="kidia-app-build__actions">
        <form method="post" data-build-form>
          <input type="hidden" name="action" value="kidia_mobile_build_app" data-build-form-action>
          <input type="hidden" name="kidia_mobile_build_nonce" value="build-nonce">
          <input type="hidden" name="kidia_mobile_download_nonce" value="download-nonce">
          <button type="submit" data-build-action>
            <span class="dashicons dashicons-smartphone" data-build-action-icon></span>
            <span data-build-action-label>Build Your App</span>
          </button>
        </form>
        <button type="button" data-build-cancel ${status === "idle" || status === "cancelled" ? "hidden" : ""}><span class="dashicons"></span><span data-build-dismiss-label>Cancel Build</span></button>
      </div>
      <div data-build-recent-choice hidden>
        <button type="button" data-build-download-again>Download Again</button>
        <button type="button" data-build-new-version>Build New Version</button>
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
      buildDownload: "Build Your App",
		download: "Download APK",
		downloaded: "Download Completed",
      cancelled: "Build cancelled.",
      cancelFailed: "The build could not be cancelled.",
      timeout: "The APK build request took too long. Please try again.",
      cancelBuild: "Cancel Build",
      ok: "OK"
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
          buildId: "build-ready-1",
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
  assert.equal(root.dataset.status, "downloaded", "The UI must move to Download Completed after starting the download.");
  assert.equal(root.querySelector("[data-build-message]").textContent, "Download Completed");
  assert.equal(root.querySelector("[data-build-progress-value]").getAttribute("aria-valuenow"), "100");
  assert.equal(root.querySelectorAll("[data-build-action]").length, 1, "Overview must expose one build/download control.");
  assert.equal(form.querySelector("[data-build-form-action]").value, "kidia_mobile_build_app");
  assert.equal(button.querySelector("[data-build-action-label]").textContent, "Build Your App");
  assert.equal(button.hidden, false, "A completed card must allow the customer to build again.");
  assert.equal(downloadSubmits, 1, "A build started by this page must download automatically when the APK becomes ready.");
}

async function testRestoredBuildDownloadsWhenProviderReturnsFinished() {
  const dom = new JSDOM(markup("building"), {
    runScripts: "outside-only",
    url: "https://store.test/wp-admin/admin.php"
  });
  const root = dom.window.document.querySelector("[data-kidia-app-build]");
  const form = root.querySelector("[data-build-form]");
  let downloadSubmits = 0;

  dom.window.kidiaAppBuilder = builderConfig();
  dom.window.fetch = async () => ({
    ok: true,
    json: async () => ({
      success: true,
      data: {
        status: "finished",
        progress: 100,
        buildId: "build-finished-1",
        message: "Your build files are ready.",
        downloadReady: true
      }
    })
  });
  dom.window.setTimeout = () => 0;
  form.addEventListener("submit", (event) => {
    if (form.querySelector("[data-build-form-action]").value === "kidia_mobile_download_apk") {
      downloadSubmits += 1;
      event.preventDefault();
    }
  });

  dom.window.eval(script);
  await flush();

  assert.equal(root.dataset.status, "downloaded", "Provider finished/completed aliases must become Download Completed after downloading.");
  assert.equal(form.querySelector("[data-build-form-action]").value, "kidia_mobile_build_app");
  assert.equal(downloadSubmits, 1, "A restored active build must download automatically when it finishes.");
}

async function testCompletedCardSurvivesBrowserReopen() {
  const dom = new JSDOM(markup("ready"), {
    runScripts: "outside-only",
    url: "https://store.test/wp-admin/admin.php"
  });
  const root = dom.window.document.querySelector("[data-kidia-app-build]");
  root.dataset.buildId = "persisted-build-1";
  dom.window.localStorage.setItem("kidiaAppBuildDownloadCompleted", "persisted-build-1");
  dom.window.kidiaAppBuilder = builderConfig();
  dom.window.eval(script);

  assert.equal(root.dataset.status, "downloaded", "Closing and reopening the browser must restore Download Completed for the same build.");
  assert.equal(root.querySelector("[data-build-message]").textContent, "Download Completed");
  assert.equal(root.querySelector("[data-build-stage]").hidden, true, "Completed builds must not repeat the terminal status beneath Download Completed.");
  assert.equal(root.querySelector("[data-build-action]").hidden, false);
  assert.equal(root.querySelector("[data-build-cancel]").hidden, false, "The completed card must remain visible until it is acknowledged.");
  assert.equal(root.querySelector("[data-build-dismiss-label]").textContent, "OK", "A completed card must replace Cancel with OK.");
  assert.equal(root.querySelector("[data-build-cancel]").classList.contains("is-confirm"), true, "OK must use the Kidia confirmation color instead of the red cancel style.");
  assert.equal(root.querySelector("[data-build-background]"), null, "Continue in background must not exist.");
}

async function testCompletedOkDismissesWithoutDeletingRecentBuild() {
  const dom = new JSDOM(markup("ready"), {
    runScripts: "outside-only",
    url: "https://store.test/wp-admin/admin.php"
  });
  const root = dom.window.document.querySelector("[data-kidia-app-build]");
  root.dataset.buildId = "preserved-build-1";
  root.dataset.completedAt = String(Math.floor(Date.now() / 1000) - 60);
  dom.window.localStorage.setItem("kidiaAppBuildDownloadCompleted", "preserved-build-1");
  let requests = 0;

  dom.window.kidiaAppBuilder = builderConfig();
  dom.window.fetch = async () => {
    requests += 1;
    return {
      ok: true,
      json: async () => ({ success: true, data: { status: "idle" } })
    };
  };
  dom.window.eval(script);

  const modal = root.querySelector("[data-build-modal]");
  assert.equal(modal.hidden, false, "A completed build must initially show its persistent card.");
  root.querySelector("[data-build-cancel]").click();
  await flush();

  assert.equal(modal.hidden, true, "OK must dismiss the completed progress card.");
  assert.equal(requests, 0, "OK must not call the destructive build-cancel endpoint.");
  assert.equal(root.dataset.status, "downloaded", "OK must preserve the completed build state.");
  assert.equal(dom.window.localStorage.getItem("kidiaAppBuildDownloadCompleted"), "preserved-build-1");

  root.querySelector("[data-build-action]").click();
  assert.equal(root.querySelector("[data-build-recent-choice]").hidden, false, "The preserved build must still offer Download Again or Build New Version.");
  assert.equal(requests, 0, "Opening the recent-build choice must not start a new build.");
}

async function testCompletedOkSurvivesCmsDomReplacement() {
  const dom = new JSDOM(markup("ready"), {
    runScripts: "outside-only",
    url: "https://store.test/wp-admin/admin.php"
  });
  const root = dom.window.document.querySelector("[data-kidia-app-build]");
  root.setAttribute("data-build-persistent", "");
  root.dataset.buildId = "replaced-build-1";
  root.dataset.completedAt = String(Math.floor(Date.now() / 1000) - 60);
  dom.window.localStorage.setItem("kidiaAppBuildDownloadCompleted", "replaced-build-1");
  let requests = 0;

  dom.window.kidiaAppBuilder = builderConfig();
  dom.window.fetch = async () => {
    requests += 1;
    return { ok: true, json: async () => ({ success: true, data: { status: "idle" } }) };
  };
  dom.window.eval(script);

  const replacement = root.cloneNode(true);
  root.replaceWith(replacement);
  replacement.querySelector("[data-build-modal]").hidden = false;
  dom.window.document.dispatchEvent(new dom.window.CustomEvent("kidia:cms-page-ready"));
  replacement.querySelector("[data-build-cancel]").click();
  await flush();

  assert.equal(replacement.querySelector("[data-build-modal]").hidden, true, "Delegated OK must still work after the CMS replaces a previously bound build card.");
  assert.equal(replacement.dataset.status, "downloaded", "Dismissing a replaced completed card must preserve its successful state.");
  assert.equal(replacement.dataset.buildId, "replaced-build-1");
  assert.equal(requests, 0, "Dismissing a replaced completed card must never call build cancellation.");
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
  assert.equal(button.disabled, true, "Build must be greyed out and unclickable while a build is active.");
  assert.equal(button.hidden, false, "The build card must remain present while progress is shown separately.");
  assert.equal(button.classList.contains("is-loading"), true, "The same button must show its loading state during a long build.");
  assert.equal(button.getAttribute("aria-busy"), "true");
  assert.equal(button.querySelector("[data-build-action-label]").textContent, "Preparing Android build. 15%", "The overview card must show the same current stage returned by the build service.");
  assert.equal(root.querySelector("[data-build-progress]").hidden, false);
  assert.equal(root.querySelector("[data-build-modal]").hidden, false, "Clicking the full card must open the build progress dialog.");
  assert.equal(root.querySelector("[data-build-cancel]").hidden, false, "Cancel must appear while the build is active.");
  assert.equal(root.querySelector("[data-build-cancel]").classList.contains("is-confirm"), false, "An active Cancel action must keep its destructive style.");
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
  assert.equal(button.querySelector("[data-build-action-label]").textContent, "Build Your App");
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
  assert.equal(button.querySelector("[data-build-action-label]").textContent, "Build Your App");
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
  assert.equal(root.querySelector("[data-build-action]").disabled, true, "A building state restored from the server must keep Build disabled.");
  assert.equal(cancelButton.hidden, false, "Cancel must be visible when the page loads with an active build.");
  cancelButton.click();
  await flush();

  assert.equal(requests.some((body) => body.includes("action=kidia_mobile_app_build_cancel")), true);
  assert.equal(requests.some((body) => body.includes("nonce=cancel-nonce")), true);
  assert.equal(root.dataset.status, "idle");
  assert.equal(modal.hidden, true);
  assert.equal(cancelButton.hidden, true);
  assert.equal(root.querySelector("[data-build-action-label]").textContent, "Build Your App");
  assert.equal(root.querySelector("[data-build-action]").disabled, false);
  assert.equal(root.querySelector("[data-build-action]").hidden, false);
}

async function testRecentBuildOffersDownloadOrNewVersion() {
  const dom = new JSDOM(markup("downloaded"), {
    runScripts: "outside-only",
    url: "https://store.test/wp-admin/admin.php"
  });
  const root = dom.window.document.querySelector("[data-kidia-app-build]");
  root.dataset.completedAt = String(Math.floor(Date.now() / 1000) - (9 * 24 * 60 * 60));
  let requests = 0;

  dom.window.kidiaAppBuilder = builderConfig();
  dom.window.fetch = async () => {
    requests += 1;
    return {
      ok: true,
      json: async () => ({ success: true, data: { status: "building", progress: 2, downloadReady: false } })
    };
  };
  dom.window.setTimeout = () => 0;
  dom.window.eval(script);

  root.querySelector("[data-build-action]").click();
  assert.equal(root.querySelector("[data-build-recent-choice]").hidden, false, "A build completed within 10 days must present both choices.");
  assert.equal(requests, 0, "Opening the recent-build choice must not start another build.");

  root.querySelector("[data-build-new-version]").click();
  await flush();
  assert.equal(root.querySelector("[data-build-recent-choice]").hidden, true);
  assert.equal(requests, 1, "Build New Version must reuse the existing build start request.");
}

async function testReadyRecentBuildOffersChoiceBeforeDownload() {
  const dom = new JSDOM(markup("ready"), {
    runScripts: "outside-only",
    url: "https://store.test/wp-admin/admin.php"
  });
  const root = dom.window.document.querySelector("[data-kidia-app-build]");
  root.dataset.completedAt = String(Math.floor(Date.now() / 1000) - (2 * 24 * 60 * 60));
  const form = root.querySelector("[data-build-form]");
  let submissions = 0;

  dom.window.kidiaAppBuilder = builderConfig();
  form.addEventListener("submit", (event) => {
    submissions += 1;
    event.preventDefault();
  });
  dom.window.eval(script);

  root.querySelector("[data-build-action]").click();
  assert.equal(root.querySelector("[data-build-recent-choice]").hidden, false, "A ready build from the last 10 days must ask before downloading or rebuilding.");
  assert.equal(submissions, 1, "The guarded submit event may fire, but must be prevented before downloading the old build.");
}

(async function () {
  await testReadyBuildDownloadsFromTheSameControl();
  await testRestoredBuildDownloadsWhenProviderReturnsFinished();
  await testCompletedCardSurvivesBrowserReopen();
  await testCompletedOkDismissesWithoutDeletingRecentBuild();
  await testCompletedOkSurvivesCmsDomReplacement();
  await testIdleControlStartsBuildAndShowsProgress();
  await testFailedBuildReturnsTheSameControlToRetry();
  await testHungStartRequestReturnsToRetry();
  await testActiveBuildCanBeCancelled();
  await testRecentBuildOffersDownloadOrNewVersion();
  await testReadyRecentBuildOffersChoiceBeforeDownload();
  console.log("APK single build-and-download control tests passed.");
})();
