(function () {
	"use strict";

	var root = document.querySelector(".kidia-page-builder");
	var frame = document.getElementById("kidia-flutter-preview");
	var form = root && root.querySelector("form.kidia-page-editor");
	if (!root || !frame || !form) { return; }

	var page = root.dataset.page || "catalog";
	var fallback = frame.parentElement && frame.parentElement.querySelector(".kidia-legacy-preview-fallback");
	var timer = 0;
	var frameOrigin = window.location.origin;
	try { frameOrigin = new URL(frame.src, window.location.href).origin; } catch (_) {}

	function pathParts(name) {
		return String(name || "").replace(/\]/g, "").split("[").filter(Boolean);
	}

	function assign(target, parts, value) {
		var cursor = target;
		parts.forEach(function (part, index) {
			var last = index === parts.length - 1;
			var nextIsIndex = /^\d+$/.test(parts[index + 1] || "");
			if (last) { cursor[part] = value; return; }
			if (!cursor[part] || typeof cursor[part] !== "object") { cursor[part] = nextIsIndex ? [] : {}; }
			cursor = cursor[part];
		});
	}

	function scalar(input) {
		if (input.type === "checkbox") { return input.checked; }
		if (input.type === "number" || input.type === "range") {
			var number = Number(input.value);
			return Number.isFinite(number) ? number : 0;
		}
		return input.value;
	}

	function layoutFromForm() {
		var result = {};
		Array.prototype.forEach.call(form.querySelectorAll("[name]"), function (input) {
			if (String(input.name || "").indexOf("layout[") !== 0) { return; }
			if (input.type === "hidden" && input.nextElementSibling && input.nextElementSibling.name === input.name && input.nextElementSibling.type === "checkbox" && input.nextElementSibling.checked) { return; }
			if ((input.type === "radio" || input.type === "checkbox") && !input.checked) { return; }
			assign(result, pathParts(input.name), scalar(input));
		});
		var layout = result.layout || {};
		layout.page = page;
		layout.elements = Array.prototype.map.call(root.querySelectorAll("#kidia-page-elements > .kidia-page-card"), function (card) {
			var id = card.dataset.element || "";
			return (layout.elements || []).find(function (element) { return element && element.id === id; }) || {id:id,type:id,enabled:true,settings:{}};
		});
		return layout;
	}

	function send() {
		if (!frame.contentWindow) { return; }
		frame.contentWindow.postMessage(JSON.stringify({
			type: "kidia-preview-layout",
			page: page,
			layout: layoutFromForm()
		}), frameOrigin);
	}

	function waitForFlutter() {
		frame.hidden = true;
		frame.setAttribute("aria-busy", "true");
		if (fallback) { fallback.hidden = false; }
	}

	function showFlutter() {
		send();
		window.requestAnimationFrame(function () {
			window.requestAnimationFrame(function () {
				frame.hidden = false;
				frame.removeAttribute("aria-busy");
				if (fallback) { fallback.hidden = true; }
			});
		});
	}

	function schedule() {
		window.clearTimeout(timer);
		timer = window.setTimeout(send, 60);
	}

	frame.addEventListener("load", send);
	form.addEventListener("input", schedule);
	form.addEventListener("change", schedule);
	document.addEventListener("kidia:preview-update", schedule);
	window.addEventListener("message", function (event) {
		if (event.source !== frame.contentWindow || event.origin !== frameOrigin) { return; }
		var message = event.data;
		if (typeof message === "string") {
			try { message = JSON.parse(message); } catch (_) { return; }
		}
		if (message && message.type === "kidia-flutter-preview-ready") { showFlutter(); }
	});

	// A cached Flutter shell can finish loading before this footer script runs.
	// Send immediately, then retry briefly so preview startup never depends on
	// catching a future iframe load/ready event.
	waitForFlutter();
	send();
	[250, 750, 1500, 3000, 6000].forEach(function (delay) {
		window.setTimeout(send, delay);
	});
}());
