(function () {
	"use strict";
	var root = document.querySelector(".kidia-builder-wrap");
	var frame = document.getElementById("kidia-flutter-preview");
	var form = document.getElementById("kidia-home-builder-form");
	if (!root || !frame || !form) { return; }
	var latestBlocks = [];
	var frameOrigin = window.location.origin;
	try { frameOrigin = new URL(frame.src, window.location.href).origin; } catch (_) {}

	function parts(name) { return String(name || "").replace(/\]/g, "").split("[").filter(Boolean); }
	function assign(target, path, value) {
		var cursor = target;
		path.forEach(function (key, index) {
			var last = index === path.length - 1;
			if (last) { cursor[key] = value; return; }
			if (!cursor[key] || typeof cursor[key] !== "object") { cursor[key] = {}; }
			cursor = cursor[key];
		});
	}
	function chrome() {
		var data = {};
		Array.prototype.forEach.call(form.querySelectorAll("[name]"), function (input) {
			var name = String(input.name || "");
			if (name.indexOf("layout[header]") !== 0 && name.indexOf("layout[footer]") !== 0) { return; }
			if (input.type === "hidden" && input.nextElementSibling && input.nextElementSibling.name === input.name && input.nextElementSibling.type === "checkbox") { return; }
			if ((input.type === "checkbox" || input.type === "radio") && !input.checked) { return; }
			var value = input.type === "checkbox" ? input.checked : input.type === "number" ? Number(input.value) : input.value;
			assign(data, parts(input.name), value);
		});
		return data.layout || {};
	}
	function send() {
		if (!frame.contentWindow) { return; }
		var layout = chrome();
		layout.page = "home";
		layout.elements = [];
		frame.contentWindow.postMessage(JSON.stringify({
			type: "kidia-preview-layout",
			page: "home",
			layout: layout,
			home: {
				version: 1,
				page: "home",
				locale: "ar",
				updated_at: new Date().toISOString(),
				blocks: latestBlocks
			}
		}), frameOrigin);
	}
	document.addEventListener("kidia:home-preview-state", function (event) {
		latestBlocks = event.detail && Array.isArray(event.detail.blocks) ? event.detail.blocks : [];
		send();
	});
	frame.addEventListener("load", send);
	window.addEventListener("message", function (event) {
		if (event.source !== frame.contentWindow || event.origin !== frameOrigin) { return; }
		var message = event.data;
		if (typeof message === "string") { try { message = JSON.parse(message); } catch (_) { return; } }
		if (message && message.type === "kidia-flutter-preview-ready") { send(); }
	});
	// Do not rely on a load event that a cached iframe may already have fired.
	send();
	[250, 750, 1500, 3000, 6000].forEach(function (delay) {
		window.setTimeout(send, delay);
	});
}());
