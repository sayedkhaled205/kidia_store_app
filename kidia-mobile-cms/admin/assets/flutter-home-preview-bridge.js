(function () {
	"use strict";
	var root = document.querySelector(".kidia-builder-wrap");
	var frame = document.getElementById("kidia-flutter-preview");
	var form = document.getElementById("kidia-home-builder-form");
	if (!root || !frame || !form) { return; }
	var config = window.kidiaHomeBuilder || {};
	var ready = false;
	var controller = null;
	var requestNumber = 0;
	var refreshTimer = 0;
	var sentInitialState = false;
	var blocks = Array.isArray(window.kidiaHomePreviewBlocks) ? window.kidiaHomePreviewBlocks : [];
	var lastSignature = "";
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
	function postJson(url, body, signal) {
		return window.fetch(String(url), {
			method: "POST", credentials: "same-origin", cache: "no-store", signal: signal,
			headers: { "Content-Type": "application/json", "X-WP-Nonce": String(config.restNonce) },
			body: JSON.stringify(body)
		}).then(function (response) {
			if (!response.ok) { throw new Error("Preview request failed with HTTP " + response.status + "."); }
			return response.json();
		});
	}
	function refresh(force) {
		var signature;
		var number;
		var signal;
		if (!ready || !config.layoutPreviewEndpoint || !config.livePreviewEndpoint || !config.restNonce || typeof window.fetch !== "function") { return; }
		signature = JSON.stringify({ layout: serializeLayout(), blocks: blocks });
		if (!force && signature === lastSignature) { return; }
		lastSignature = signature;
		if (controller) { controller.abort(); }
		controller = typeof window.AbortController === "function" ? new window.AbortController() : null;
		signal = controller ? controller.signal : undefined;
		number = ++requestNumber;
		Promise.all([
			postJson(config.layoutPreviewEndpoint, { layout: serializeLayout() }, signal),
			postJson(config.livePreviewEndpoint, { blocks: blocks }, signal)
		]).then(function (payloads) {
			if (number !== requestNumber || !frame.contentWindow) { return; }
			frame.contentWindow.postMessage(JSON.stringify({ type: "kidia-preview-layout", page: "home", layout: payloads[0], home: payloads[1] }), frameOrigin);
		}).catch(function (error) {
			if (error && error.name === "AbortError") { return; }
			if (window.console && window.console.warn) { window.console.warn(error); }
		});
	}
	function queueRefresh(force) {
		window.clearTimeout(refreshTimer);
		if (force) {
			refresh(true);
			return;
		}
		// Typing and range controls can emit several events per frame. A short
		// debounce keeps the UI live without piling up expensive product queries.
		refreshTimer = window.setTimeout(function () {
			refresh(false);
		}, 140);
	}
	window.addEventListener("message", function (event) {
		if (event.source !== frame.contentWindow || event.origin !== frameOrigin) { return; }
		var message = event.data;
		if (typeof message === "string") { try { message = JSON.parse(message); } catch (_) { return; } }
		if (message && message.type === "kidia-flutter-preview-ready") {
			ready = true;
			showFlutter();
			if (!sentInitialState) {
				sentInitialState = true;
				queueRefresh(true);
			}
		}
	});
	frame.addEventListener("load", function () {
		ready = false;
		sentInitialState = false;
		lastSignature = "";
	});
	form.addEventListener("input", function () { queueRefresh(false); });
	form.addEventListener("change", function () { queueRefresh(false); });
	document.addEventListener("kidia:home-preview-state", function (event) {
		if (event.detail && Array.isArray(event.detail.blocks)) { blocks = event.detail.blocks; queueRefresh(false); }
	});
	document.addEventListener("kidia:home-preview-focus", function (event) {
		var target = event.detail && String(event.detail.target || "");
		if (!target || !ready || !frame.contentWindow) { return; }
		frame.contentWindow.postMessage(JSON.stringify({
			type: "kidia-preview-focus",
			page: "home",
			target: target
		}), frameOrigin);
	});
	frame.addEventListener("mouseenter", function () {
		// Give the embedded Flutter surface the wheel/trackpad events while the
		// pointer is over the phone, without requiring an initial click.
		try { frame.contentWindow.focus(); } catch (_) {}
	});
	// Do not rely on a load event that a cached iframe may already have fired.
	waitForFlutter();
}());
