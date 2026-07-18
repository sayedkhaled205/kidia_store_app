(function () {
	"use strict";

	var labels = {
		image: "Image Settings",
		text: "Text & Content",
		layout: "Layout & Spacing",
		colors: "Colors & Appearance",
		actions: "Actions & Navigation",
		visibility: "Visibility & Display",
		products: "Products & Data",
		search: "Search Settings",
		cart: "Cart Settings",
		account: "Account Settings",
		icons: "Icons",
		pagination: "Pagination",
		general: "General Settings"
	};

	function sectionFor(node) {
		var value = ((node.querySelector("label") || {}).textContent || "") + " " +
			Array.prototype.map.call(node.querySelectorAll("input,select,textarea"), function (input) { return input.name || ""; }).join(" ");
		value = value.toLowerCase();
		if (/pagination|products_per_page|load more|loader/.test(value)) { return "pagination"; }
		if (/search/.test(value)) { return "search"; }
		if (/cart|bag/.test(value)) { return "cart"; }
		if (/account|profile|avatar/.test(value)) { return "account"; }
		if (/icon/.test(value)) { return "icons"; }
		if (/image|logo|photo|thumbnail|gallery|video|media|fit|zoom/.test(value)) { return "image"; }
		if (/action|url|link|route|product_id|category_id|brand|collection/.test(value)) { return "actions"; }
		if (/source|manual_product|limit|columns|product|sort|filter/.test(value)) { return "products"; }
		if (/show|hide|enabled|visible|visibility|sticky/.test(value)) { return "visibility"; }
		if (/color|background|border|shadow|effect|style|radius|shape/.test(value)) { return "colors"; }
		if (/title|subtitle|label|text|font|description|placeholder|line_height/.test(value)) { return "text"; }
		if (/height|width|size|gap|padding|spacing|margin|ratio|layout|align|position|order/.test(value)) { return "layout"; }
		return "general";
	}

	function addHeadings(container) {
		if (!container || container.dataset.kidiaSectioned === "1") { return; }
		Array.prototype.forEach.call(container.querySelectorAll(":scope > .kidia-settings-section-title"), function (heading) { heading.remove(); });
		var children = Array.prototype.filter.call(container.children, function (node) {
			return !node.classList.contains("kidia-settings-section-title") && (node.querySelector("input,select,textarea,button") || node.matches("label"));
		});
		var buckets = {};
		children.forEach(function (node) {
			var section = sectionFor(node);
			if (!buckets[section]) { buckets[section] = []; }
			buckets[section].push(node);
		});
		Object.keys(labels).forEach(function (section) {
			if (buckets[section] && buckets[section].length) {
				var heading = document.createElement("div");
				heading.className = "kidia-settings-section-title kidia-settings-section-title--" + section;
				heading.textContent = labels[section];
				container.appendChild(heading);
				buckets[section].forEach(function (node) { container.appendChild(node); });
			}
		});
		container.dataset.kidiaSectioned = "1";
	}

	function sectionAll(root) {
		(root || document).querySelectorAll(".kidia-page-fields,.kidia-builder-settings-content,.kidia-category-settings").forEach(addHeadings);
	}

	document.addEventListener("DOMContentLoaded", function () {
		sectionAll(document);
		if (window.MutationObserver) {
			new MutationObserver(function (records) { records.forEach(function (record) { record.addedNodes.forEach(function (node) { if (node.nodeType === 1) { sectionAll(node); } }); }); }).observe(document.body, { childList: true, subtree: true });
		}
	});
}());
