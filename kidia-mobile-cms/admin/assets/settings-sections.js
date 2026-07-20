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
		wishlist: "Wishlist Settings",
		account: "Account Settings",
		icons: "Icons",
		pagination: "Pagination",
		section_layout: "Section Layout Settings",
		filter_options: "Available Filters",
		general: "General Settings"
	};
	var sectionLayoutPattern = /\[(?:margin_top|margin_bottom|space_up|space_down|block_background|element_background_color)\]$/;

	function sectionFor(node) {
		if (node.classList.contains("kidia-section-layout-field")) { return "section_layout"; }
		if (node.classList.contains("kidia-slider-image-setting")) { return "image"; }
		var value = ((node.querySelector("label") || {}).textContent || "") + " " +
			Array.prototype.map.call(node.querySelectorAll("input,select,textarea"), function (input) { return input.name || ""; }).join(" ");
		value = value.toLowerCase();
		if (Array.prototype.some.call(node.querySelectorAll("input,select,textarea"), function (input) { return sectionLayoutPattern.test(input.name || ""); })) { return "section_layout"; }
		if (/quick_add|quick add/.test(value)) { return "cart"; }
		if (/product_wishlist|product wishlist/.test(value)) { return "wishlist"; }
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
			var element = container.closest("[data-element]");
			if (element && element.dataset.element === "product_grid" && section !== "section_layout") { section = "general"; }
			if (element && element.dataset.element === "filter_bar" && section !== "section_layout") {
				var input = node.querySelector("input[name],select[name],textarea[name]");
				var match = input && input.name.match(/\[settings\]\[([^\]]+)\]/);
				var key = match ? match[1] : "";
				if (/^(sticky|show_filter|show_sort|show_result_count)$/.test(key)) { section = "visibility"; }
				else if (/^filter_(price|sale|brand|size)$/.test(key)) { section = "filter_options"; }
				else if (/color$/.test(key)) { section = "colors"; }
				else { section = "layout"; }
			}
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
		var finalHeading = container.querySelector(":scope > .kidia-settings-section-title--section_layout");
		if (finalHeading) {
			container.appendChild(finalHeading);
			container.appendChild(buildSectionLayoutGrid(buckets.section_layout || []));
			container.classList.add("has-section-layout-settings");
		}
		container.dataset.kidiaSectioned = "1";
	}

	function sectionLayoutKey(field) {
		var input = field.querySelector("input[name],select[name],textarea[name]");
		var match = input && input.name.match(/\[([^\]]+)\]$/);
		return match ? match[1] : "";
	}

	function buildSectionLayoutGrid(fields) {
		var grid = document.createElement("div");
		grid.className = "kidia-section-layout-grid";
		var groups = [
			{ name: "merge", keys: ["margin_top", "margin_bottom"] },
			{ name: "space", keys: ["space_up", "space_down"] },
			{ name: "background", keys: ["block_background", "background_color", "element_background_color"] }
		];
		var used = [];
		groups.forEach(function (group) {
			var column = document.createElement("div");
			column.className = "kidia-section-layout-column kidia-section-layout-column--" + group.name;
			group.keys.forEach(function (key) {
				fields.forEach(function (field) {
					if (used.indexOf(field) === -1 && sectionLayoutKey(field) === key) {
						used.push(field);
						column.appendChild(field);
					}
				});
			});
			grid.appendChild(column);
		});
		fields.forEach(function (field) {
			if (used.indexOf(field) === -1) { grid.lastElementChild.appendChild(field); }
		});
		return grid;
	}

	function sectionAll(root) {
		root = root || document;
		var selector = ".kidia-page-fields,.kidia-builder-settings-content,.kidia-category-settings,.kidia-category-general-fields";
		var containers = Array.prototype.slice.call(root.querySelectorAll(selector));
		if (root.matches && root.matches(selector)) { containers.unshift(root); }
		containers.forEach(function (container) {
			/* Header/footer settings have their own item-based organization. */
			if (!container.closest(".kidia-chrome-settings")) { addHeadings(container); }
		});
		enhanceProductPositions(root);
		updateRanges(root);
	}

	function updateRange(input) {
		var min = Number(input.min || 0);
		var max = Number(input.max || 100);
		var value = Number(input.value || min);
		var progress = max > min ? Math.max(0, Math.min(100, ((value - min) / (max - min)) * 100)) : 0;
		input.style.setProperty("--kidia-range-progress", progress + "%");
	}

	function updateRanges(root) {
		if (root.matches && root.matches('input[type="range"]')) { updateRange(root); }
		root.querySelectorAll('input[type="range"]').forEach(updateRange);
	}

	function enhanceProductPositions(root) {
		root.querySelectorAll('select[name$="[quick_add_position]"],select[name$="[product_wishlist_position]"]').forEach(function (select) {
			if (select.dataset.kidiaPositionEnhanced === "1") { return; }
			select.dataset.kidiaPositionEnhanced = "1";
			select.hidden = true;
			var picker = document.createElement("div");
			picker.className = "kidia-product-position";
			picker.innerHTML = '<div class="kidia-product-position__image" aria-hidden="true"></div>';
			Array.prototype.forEach.call(select.options, function (option) {
				var label = document.createElement("label");
				label.className = "is-" + option.value;
				label.title = option.textContent;
				var input = document.createElement("input");
				input.type = "radio";
				input.name = select.name + "_visual";
				input.checked = option.value === select.value;
				input.addEventListener("change", function () {
					if (!input.checked) { return; }
					select.value = option.value;
					select.dispatchEvent(new Event("change", { bubbles: true }));
					select.dispatchEvent(new Event("input", { bubbles: true }));
				});
				label.appendChild(input);
				label.appendChild(document.createElement("span"));
				picker.appendChild(label);
			});
			select.insertAdjacentElement("afterend", picker);
		});
	}

	document.addEventListener("DOMContentLoaded", function () {
		sectionAll(document);
		document.addEventListener("input", function (event) { if (event.target.matches && event.target.matches('input[type="range"]')) { updateRange(event.target); } });
		if (window.MutationObserver) {
			new MutationObserver(function (records) { records.forEach(function (record) { record.addedNodes.forEach(function (node) { if (node.nodeType === 1) { sectionAll(node); } }); }); }).observe(document.body, { childList: true, subtree: true });
		}
	});
}());
