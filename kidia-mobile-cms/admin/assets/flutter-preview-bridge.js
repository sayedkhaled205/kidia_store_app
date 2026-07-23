(function () {
	"use strict";

	var root = document.querySelector(".kidia-page-builder");
	var frame = document.getElementById("kidia-flutter-preview");
	var form = root && root.querySelector("form.kidia-page-editor");
	if (!root || !frame || !form) { return; }

	var page = root.dataset.page || "catalog";
	var config = window.kidiaFlutterPreview || {};
	var ready = false;
	var controller = null;
	var requestNumber = 0;
	var fallback = frame.parentElement && frame.parentElement.querySelector(".kidia-legacy-preview-fallback");
	var frameOrigin = window.location.origin;
	try { frameOrigin = new URL(frame.src, window.location.href).origin; } catch (_) {}

	function waitForFlutter() {
		// Keep the real Flutter surface visible while its own loading state is
		// shown. An HTML replica can drift from the mobile widgets.
		frame.hidden = false;
		frame.setAttribute("aria-busy", "true");
		if (fallback) { fallback.hidden = true; }
	}

	function showFlutter() {
		window.requestAnimationFrame(function () {
			window.requestAnimationFrame(function () {
				frame.hidden = false;
				frame.removeAttribute("aria-busy");
				if (fallback) { fallback.hidden = true; }
			});
		});
	}

	function setPath(target, name, value) {
		var keys = String(name).replace(/\]/g, "").split("[");
		var cursor = target;
		keys.forEach(function (key, index) {
			var last = index === keys.length - 1;
			var nextIsIndex = !last && /^\d+$/.test(keys[index + 1]);
			if (last) { cursor[key] = value; return; }
			if (!cursor[key] || typeof cursor[key] !== "object") { cursor[key] = nextIsIndex ? [] : {}; }
			cursor = cursor[key];
		});
	}

	function serializeLayout() {
		var result = {};
		Array.prototype.forEach.call(form.elements, function (field) {
			if (!field.name || field.disabled || field.name.indexOf("layout[") !== 0) { return; }
			if ((field.type === "checkbox" || field.type === "radio") && !field.checked) { return; }
			setPath(result, field.name, field.value);
		});
		return result.layout || {};
	}

	function sendLayout(layout) {
		if (!ready || !frame.contentWindow) { return; }
		frame.contentWindow.postMessage(JSON.stringify({ type: "kidia-preview-layout", page: page, layout: layout }), frameOrigin);
	}

	function refresh() {
		var number;
		if (!config.layoutPreviewEndpoint || !config.restNonce || typeof window.fetch !== "function") { return; }
		if (controller) { controller.abort(); }
		controller = typeof window.AbortController === "function" ? new window.AbortController() : null;
		number = ++requestNumber;
		window.fetch(String(config.layoutPreviewEndpoint), {
			method: "POST", credentials: "same-origin", cache: "no-store",
			headers: { "Content-Type": "application/json", "X-WP-Nonce": String(config.restNonce) },
			body: JSON.stringify({ layout: serializeLayout() }),
			signal: controller ? controller.signal : undefined
		}).then(function (response) {
			if (!response.ok) { throw new Error("Preview request failed with HTTP " + response.status + "."); }
			return response.json();
		}).then(function (layout) {
			if (number === requestNumber) { sendLayout(layout); }
		}).catch(function (error) {
			if (error && error.name === "AbortError") { return; }
			if (window.console && window.console.warn) { window.console.warn(error); }
		});
	}

	window.addEventListener("message", function (event) {
		if (event.source !== frame.contentWindow || event.origin !== frameOrigin) { return; }
		var message = event.data;
		if (typeof message === "string") {
			try { message = JSON.parse(message); } catch (_) { return; }
		}
		if (message && message.type === "kidia-flutter-preview-ready") { ready = true; showFlutter(); refresh(); }
	});
	form.addEventListener("input", refresh);
	form.addEventListener("change", refresh);
	document.addEventListener("kidia:page-layout-changed", refresh);

	// A cached Flutter shell can finish loading before this footer script runs.
	waitForFlutter();
}());
