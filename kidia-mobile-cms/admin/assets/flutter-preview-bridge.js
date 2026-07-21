(function () {
	"use strict";

	var root = document.querySelector(".kidia-page-builder");
	var frame = document.getElementById("kidia-flutter-preview");
	var form = root && root.querySelector("form.kidia-page-editor");
	if (!root || !frame || !form) { return; }

	var page = root.dataset.page || "catalog";
	var timer = 0;

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
		Array.prototype.forEach.call(form.querySelectorAll('[name^="layout["]'), function (input) {
			if (input.type === "hidden" && input.nextElementSibling && input.nextElementSibling.name === input.name && input.nextElementSibling.type === "checkbox") { return; }
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
		}), window.location.origin);
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
		if (event.origin !== window.location.origin) { return; }
		var message = event.data;
		if (typeof message === "string") {
			try { message = JSON.parse(message); } catch (_) { return; }
		}
		if (message && message.type === "kidia-flutter-preview-ready") { send(); }
	});
}());
