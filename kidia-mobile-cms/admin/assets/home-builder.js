(function () {
	"use strict";

	var builder = document.getElementById("kidia-home-builder");
	var form = document.getElementById("kidia-home-builder-form");

	if (!builder || !form) {
		return;
	}

	window.kidiaHomeBuilderBooted = true;

	var config = window.kidiaHomeBuilder || {};
	var labels = config.labels || {};
	var picker = document.getElementById("kidia-element-picker");
	var createModal = document.getElementById("kidia-create-element-modal");
	var searchInput = document.getElementById("kidia-element-picker-search");
	var createNameInput = document.getElementById("kidia-create-element-name");
	var createError = document.getElementById("kidia-create-element-error");
	var createTitle = document.getElementById("kidia-create-element-title");
	var blocksPayload = document.getElementById("kidia-home-builder-payload");
	var previewContent = document.getElementById("kidia-mobile-preview-content");
	var currentCreateType = "";
	var draggedBlock = null;
	var isDirty = false;
	var previewBlocksById = {};
	var previewBlocksByType = {};

	function toArray(collection) {
		return Array.prototype.slice.call(collection || []);
	}

	function replaceEvery(value, search, replacement) {
		return String(value).split(search).join(replacement);
	}

	function getBlocks() {
		return toArray(builder.querySelectorAll(".kidia-builder-block"));
	}

	function generateId(type) {
		return type + "_" + Date.now().toString(36) + "_" + Math.random().toString(36).slice(2, 8);
	}

	function markDirty() {
		isDirty = true;
	}

	function updateIndexes() {
		getBlocks().forEach(function (block, index) {
			toArray(block.querySelectorAll('[name^="blocks["]')).forEach(function (input) {
				input.name = input.name.replace(/blocks\[[^\]]+\]/, "blocks[" + index + "]");
			});

			var orderInput = block.querySelector(".kidia-block-order");
			if (orderInput) {
				orderInput.value = String(index + 1);
			}

			reindexHeroItems(block);
			reindexRepeatableItems(block);
		});
	}

	function settingPath(name) {
		var match = String(name || "").match(/\[settings\]((?:\[[^\]]*\])+)/);
		var path = [];
		var part;
		var pattern;

		if (!match) {
			return path;
		}

		pattern = /\[([^\]]*)\]/g;
		while ((part = pattern.exec(match[1])) !== null) {
			path.push(part[1]);
		}

		return path;
	}

	function assignSetting(root, path, value) {
		var cursor = root;

		path.forEach(function (key, index) {
			var last = index === path.length - 1;
			var nextKey = path[index + 1];

			if (last) {
				if (key === "" && Array.isArray(cursor)) {
					cursor.push(value);
				} else if (Object.prototype.hasOwnProperty.call(cursor, key)) {
					cursor[key] = Array.isArray(cursor[key]) ? cursor[key].concat(value) : [cursor[key], value];
				} else {
					cursor[key] = value;
				}
				return;
			}

			if (!Object.prototype.hasOwnProperty.call(cursor, key)) {
				cursor[key] = /^\d+$/.test(nextKey) || nextKey === "" ? [] : {};
			}

			cursor = cursor[key];
		});
	}

	function serializeBlocks() {
		return getBlocks().map(function (block, index) {
			function value(selector) {
				var field = block.querySelector(selector);
				return field ? field.value || "" : "";
			}

			var enabled = block.querySelector('input[name$="[enabled]"]');
			var settings = {};

			toArray(block.querySelectorAll('[name*="[settings]"]')).forEach(function (input) {
				var tagName = String(input.tagName || "").toLowerCase();
				var inputType = String(input.type || "").toLowerCase();
				var path;
				var serializedValue;

				if (tagName !== "input" && tagName !== "select" && tagName !== "textarea") {
					return;
				}

				if (inputType === "radio" && !input.checked) {
					return;
				}

				path = settingPath(input.name);
				if (!path.length) {
					return;
				}

				serializedValue = inputType === "checkbox" && !input.checked ? "" : input.value;
				assignSetting(settings, path, serializedValue);
			});

			return {
				id: value(".kidia-block-id"),
				library_id: value(".kidia-block-library-id"),
				source_library_id: value(".kidia-block-source-library-id"),
				create_intent: value(".kidia-block-create-intent"),
				type: value(".kidia-block-type"),
				name: value(".kidia-block-name-input"),
				enabled: enabled && enabled.checked ? "1" : "",
				status: value(".kidia-block-status"),
				order: index + 1,
				settings: settings
			};
		});
	}

	function escapeHtml(value) {
		return String(value === null || typeof value === "undefined" ? "" : value).replace(/[&<>"']/g, function (character) {
			return {
				"&": "&amp;",
				"<": "&lt;",
				">": "&gt;",
				'"': "&quot;",
				"'": "&#039;"
			}[character];
		});
	}

	function safeImage(value) {
		var url = String(value === null || typeof value === "undefined" ? "" : value).trim();
		return /^https?:\/\//i.test(url) ? escapeHtml(url) : "";
	}

	function safeColor(value, fallback) {
		var color = String(value || "").trim();
		return /^#[0-9a-f]{3,8}$/i.test(color) ? color : fallback;
	}

	function numberInRange(value, fallback, minimum, maximum) {
		var number = Number(value);
		if (!isFinite(number)) {
			number = fallback;
		}
		return Math.max(minimum, Math.min(maximum, number));
	}

	function valueFromSettings(settings, runtimeData, key, fallback) {
		if (Object.prototype.hasOwnProperty.call(settings, key)) {
			return settings[key];
		}

		if (runtimeData && Object.prototype.hasOwnProperty.call(runtimeData, key)) {
			return runtimeData[key];
		}

		return fallback;
	}

	function blockHeading(settings, fallback, runtimeData) {
		var title = escapeHtml(valueFromSettings(settings, runtimeData, "title", fallback) || "");
		var subtitle = escapeHtml(valueFromSettings(settings, runtimeData, "subtitle", "") || "");
		var showViewAll = valueFromSettings(settings, runtimeData, "show_view_all", "");
		var viewAllLabel = escapeHtml(valueFromSettings(settings, runtimeData, "view_all_label", "عرض الكل") || "عرض الكل");

		if (!title && !subtitle) {
			return "";
		}

		return '<div class="kidia-preview-section-heading"><div><strong>' + title + "</strong>" + (subtitle ? "<small>" + subtitle + "</small>" : "") + "</div>" + (showViewAll ? "<span>" + viewAllLabel + " ‹</span>" : "") + "</div>";
	}

	function sampleCards(count, className, label) {
		var cards = [];
		var index;
		for (index = 0; index < count; index += 1) {
			cards.push('<div class="' + className + '"><span class="kidia-preview-sample-image"></span>' + (label ? "<strong>" + escapeHtml(label) + "</strong>" : "") + "</div>");
		}
		return cards.join("");
	}

	function registerPreviewBlocks(blocks) {
		previewBlocksById = {};
		previewBlocksByType = {};

		if (!Array.isArray(blocks)) {
			return;
		}

		blocks.forEach(function (block) {
			var id;
			var type;

			if (!block || typeof block !== "object") {
				return;
			}

			id = String(block.id || "");
			type = String(block.type || "");

			if (id) {
				previewBlocksById[id] = block;
			}

			if (type) {
				if (!previewBlocksByType[type]) {
					previewBlocksByType[type] = [];
				}
				previewBlocksByType[type].push(block);
			}
		});
	}

	function runtimePreviewBlock(block) {
		var references = [block.id, block.library_id, block.source_library_id];
		var match = null;

		references.some(function (reference) {
			var candidate = previewBlocksById[String(reference || "")];
			if (candidate && candidate.type === block.type) {
				match = candidate;
				return true;
			}
			return false;
		});

		if (match) {
			return match;
		}

		return previewBlocksByType[block.type] && previewBlocksByType[block.type].length
			? previewBlocksByType[block.type][0]
			: null;
	}

	function runtimePreviewData(block) {
		var runtimeBlock = runtimePreviewBlock(block);
		return runtimeBlock && runtimeBlock.data && typeof runtimeBlock.data === "object"
			? runtimeBlock.data
			: {};
	}

	function limitedItems(items, limit, maximum) {
		var resolvedLimit = Math.round(numberInRange(limit, maximum, 1, maximum));
		return Array.isArray(items) ? items.slice(0, resolvedLimit) : [];
	}

	function renderCategoryCard(item, showName, settings) {
		var image = safeImage(item && item.image_url);
		var name = escapeHtml(item && item.name ? item.name : "Category");
		var radius = settings.image_shape === "circle" ? "50%" : (settings.image_shape === "square" ? "0" : "10px");

		return '<article class="kidia-preview-category-card"><span class="kidia-preview-category-card__image" style="border-radius:' + radius + '">' + (image ? '<img src="' + image + '" alt="' + name + '">' : '<span class="kidia-preview-image-fallback"></span>') + "</span>" + (showName ? '<strong style="color:' + safeColor(settings.label_color, "#1F2933") + ';font-size:' + numberInRange(settings.label_size, 13, 10, 22) * 0.62 + 'px">' + name + "</strong>" : "") + "</article>";
	}

	function renderProductCard(item, settings) {
		var image = safeImage(item && item.image_url);
		var name = escapeHtml(item && item.name ? item.name : "Product");
		var price = escapeHtml(item && item.price !== null && typeof item.price !== "undefined" ? item.price : "");
		var regularPrice = escapeHtml(item && item.regular_price ? item.regular_price : "");
		var currency = escapeHtml(item && item.currency_symbol ? item.currency_symbol : "");
		var inStock = !item || item.in_stock !== false;
		var badge = escapeHtml(item && item.badge ? item.badge : "");
		var status = !inStock ? "نفد المخزون" : badge;
		var discounted = regularPrice && regularPrice !== price;
		var rating = Number(item && item.rating ? item.rating : 0);
		var style = settings && settings.card_style ? settings.card_style : "outlined";

		return '<article class="kidia-preview-product-card is-' + escapeHtml(style) + '" style="border-radius:' + numberInRange(settings && settings.card_radius, 20, 0, 40) * 0.65 + 'px"><div class="kidia-preview-product-card__image" style="aspect-ratio:' + numberInRange(settings && settings.image_ratio, 1, 0.6, 1.8) + '">' + (image ? '<img src="' + image + '" alt="' + name + '">' : '<span class="kidia-preview-image-fallback"></span>') + (status && (!settings || settings.show_badge !== "") ? '<span class="kidia-preview-product-card__badge' + (!inStock ? " is-out-of-stock" : "") + '">' + status + "</span>" : "") + '</div><div class="kidia-preview-product-card__body">' + (!settings || settings.show_name !== "" ? "<strong>" + name + "</strong>" : "") + (settings && settings.show_rating !== "" && rating > 0 ? '<span class="kidia-preview-product-card__rating">★ ' + rating.toFixed(1) + "</span>" : "") + (!settings || settings.show_price !== "" ? '<div class="kidia-preview-product-card__prices"><b>' + price + (currency ? " " + currency : "") + "</b>" + (discounted && (!settings || settings.show_regular_price !== "") ? "<del>" + regularPrice + (currency ? " " + currency : "") + "</del>" : "") + "</div>" : "") + "</div></article>";
	}

	function renderBrandCard(item, itemWidth, settings) {
		var image = safeImage(item && item.logo_url);
		var name = escapeHtml(item && item.name ? item.name : "Brand");
		var width = numberInRange(itemWidth, 92, 60, 180) * 0.68;
		var radius = settings.image_shape === "circle" ? "50%" : (settings.image_shape === "square" ? "0" : "12px");

		return '<article class="kidia-preview-brand-card" style="--kidia-preview-brand-width:' + width + 'px"><span class="kidia-preview-brand-card__image" style="border-radius:' + radius + '">' + (image ? '<img src="' + image + '" alt="' + name + '">' : '<span class="kidia-preview-image-fallback"></span>') + "</span>" + (settings.show_names === "" ? "" : "<strong>" + name + "</strong>") + "</article>";
	}

	function renderQuickLink(item, settings) {
		var image = safeImage(item && item.image_url);
		var label = escapeHtml(item && item.label ? item.label : "Link");
		var subtitle = escapeHtml(item && item.subtitle ? item.subtitle : "");
		var shape = settings.image_shape === "circle" ? "50%" : (settings.image_shape === "square" ? "0" : "12px");
		return '<article class="kidia-preview-quick-link"><span style="border-radius:' + shape + '">' + (image ? '<img src="' + image + '" alt="' + label + '">' : '<span class="kidia-preview-image-fallback"></span>') + "</span>" + (settings.show_labels === "" ? "" : '<strong style="color:' + safeColor(settings.label_color, "#1F2933") + ';font-size:' + numberInRange(settings.label_size, 13, 10, 22) * 0.62 + 'px">' + label + "</strong>" + (subtitle ? "<small>" + subtitle + "</small>" : "")) + "</article>";
	}

	function renderBannerTile(item, settings) {
		var image = safeImage(item && item.image_url);
		var title = escapeHtml(item && item.title ? item.title : "");
		var subtitle = escapeHtml(item && item.subtitle ? item.subtitle : "");
		var button = escapeHtml(item && item.button_label ? item.button_label : "");
		var overlay = numberInRange(settings.overlay_strength, 35, 0, 90) / 100;
		return '<article class="kidia-preview-banner-tile" style="aspect-ratio:' + numberInRange(settings.aspect_ratio, 1, 0.45, 5) + ";border-radius:" + numberInRange(settings.border_radius, 16, 0, 48) + 'px">' + (image ? '<img src="' + image + '" alt="" style="object-fit:' + (settings.image_fit === "contain" ? "contain" : "cover") + '">' : '<span class="kidia-preview-image-fallback"></span>') + ((title || subtitle || button) ? '<div style="background:linear-gradient(0deg,rgba(0,0,0,' + overlay + '),transparent);color:' + safeColor(settings.text_color, "#FFFFFF") + '"><strong>' + title + "</strong><small>" + subtitle + "</small>" + (button ? "<b>" + button + "</b>" : "") + "</div>" : "") + "</article>";
	}

	function previewIcon(type) {
		var drawing = {
			account: '<circle cx="12" cy="8" r="3"></circle><path d="M5.5 19c.8-3.2 3-4.8 6.5-4.8s5.7 1.6 6.5 4.8"></path>',
			search: '<circle cx="10.5" cy="10.5" r="5.5"></circle><path d="m15 15 4 4"></path>',
			cart: '<path d="M6.5 8.5h11l1 11h-13z"></path><path d="M9 9V7a3 3 0 0 1 6 0v2"></path>'
		}[type] || "";

		return '<span class="kidia-preview-header__icon" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false">' + drawing + "</svg></span>";
	}

	function renderBlock(block) {
		var settings = block.settings || {};
		var runtimeData = runtimePreviewData(block);
		var name = escapeHtml(block.name || replaceEvery(block.type, "_", " "));
		var image;
		var items;
		var item;
		var ratio;
		var columns;
		var count;
		var title;
		var subtitle;
		var background;
		var textColor;

		switch (block.type) {
		case "app_header":
			image = safeImage(settings.logo_url);
			title = escapeHtml(settings.title || name || "Kidia Store");
			subtitle = escapeHtml(settings.subtitle || "");
			return '<div class="kidia-preview-header' + (settings.search_style === "bar" ? " has-search-bar" : "") + '" style="min-height:' + numberInRange(settings.height, 64, 48, 120) + "px;color:" + safeColor(settings.title_color, "#1F2933") + ";background:" + safeColor(settings.background_color, "#FFFFFF") + '"><span class="kidia-preview-header__identity">' + (image ? '<img src="' + image + '" alt="" style="height:' + numberInRange(settings.logo_height, 38, 20, 80) + 'px">' : "<strong>" + title + "</strong>" + (subtitle ? "<small>" + subtitle + "</small>" : "")) + '</span><span class="kidia-preview-header__icons" style="color:' + safeColor(settings.icon_color, "#1F2933") + '">' + (settings.show_account ? previewIcon("account") : "") + (settings.show_search && settings.search_style !== "bar" ? previewIcon("search") : "") + (settings.show_cart ? previewIcon("cart") : "") + "</span>" + (settings.show_search && settings.search_style === "bar" ? '<span class="kidia-preview-header__search" style="background:' + safeColor(settings.search_background, "#F1F3F4") + ";color:" + safeColor(settings.search_text_color, "#5F6368") + '">' + previewIcon("search") + escapeHtml(settings.search_placeholder || "Search products") + "</span>" : "") + "</div>";

		case "hero_slider":
			items = Array.isArray(settings.items) ? settings.items.filter(function (slide) { return slide && slide.enabled !== ""; }) : [];
			item = items[0] || {};
			image = safeImage(item.image_url);
			ratio = numberInRange(settings.aspect_ratio, 1.8, 0.45, 4);
			return '<div class="kidia-preview-block kidia-preview-hero is-' + escapeHtml(settings.overlay_position || "start") + '" style="aspect-ratio:' + ratio + ";margin-inline:" + numberInRange(settings.horizontal_padding, 16, 0, 32) * 0.5 + "px;border-radius:" + numberInRange(settings.border_radius, 24, 0, 48) * 0.5 + 'px">' + (image ? '<img src="' + image + '" alt="" style="object-fit:' + (settings.image_fit === "contain" ? "contain" : "cover") + '">' : '<div class="kidia-preview-placeholder">' + name + "</div>") + ((item.title || item.subtitle || item.button_label) ? '<div class="kidia-preview-hero__copy" style="background:rgba(17,24,39,' + numberInRange(settings.overlay_strength, 72, 0, 95) / 100 + ");color:" + safeColor(settings.text_color, "#FFFFFF") + '"><strong>' + escapeHtml(item.title || "") + "</strong><small>" + escapeHtml(item.subtitle || "") + "</small>" + (item.button_label ? "<b>" + escapeHtml(item.button_label) + "</b>" : "") + "</div>" : "") + (items.length > 1 && settings.show_indicators !== "" ? '<div class="kidia-preview-dots is-' + escapeHtml(settings.indicator_style || "pill") + '">' + items.map(function (_, index) { return "<i" + (index === 0 ? ' class="is-active"' : "") + "></i>"; }).join("") + "</div>" : "") + "</div>";

		case "category_grid":
			columns = Math.round(numberInRange(settings.columns, 4, 2, 6));
			count = Math.round(numberInRange(settings.limit, 8, 1, 12));
			items = limitedItems(runtimeData.items, count, 12);
			return '<section class="kidia-preview-section">' + blockHeading(settings, name, runtimeData) + '<div class="kidia-preview-category-grid' + (settings.layout === "carousel" ? " is-carousel" : "") + '" style="--kidia-preview-columns:' + columns + ";gap:" + numberInRange(settings.gap, 12, 0, 32) * 0.55 + 'px">' + (items.length ? items.map(function (category) { return renderCategoryCard(category, settings.show_names !== "", settings); }).join("") : sampleCards(count, "kidia-preview-category-card", settings.show_names === "" ? "" : "Category")) + "</div></section>";

		case "image_banner":
			image = safeImage(settings.image_url);
			ratio = numberInRange(settings.aspect_ratio, 2.4, 0.45, 5);
			return '<div class="kidia-preview-block kidia-preview-banner" style="aspect-ratio:' + ratio + ";border-radius:" + numberInRange(settings.border_radius, 20, 0, 60) + 'px">' + (image ? '<img src="' + image + '" alt="' + escapeHtml(settings.semantic_label || "") + '" style="object-fit:' + (settings.image_fit === "contain" ? "contain" : "cover") + '">' : '<div class="kidia-preview-placeholder">' + name + "</div>") + ((settings.title || settings.subtitle || settings.button_label) ? '<div class="kidia-preview-banner__overlay" style="background:linear-gradient(0deg,rgba(0,0,0,' + numberInRange(settings.overlay_strength, 0, 0, 95) / 100 + '),transparent);color:' + safeColor(settings.text_color, "#FFFFFF") + '"><strong>' + escapeHtml(settings.title || "") + "</strong><small>" + escapeHtml(settings.subtitle || "") + "</small>" + (settings.button_label ? "<b>" + escapeHtml(settings.button_label) + "</b>" : "") + "</div>" : "") + "</div>";

		case "product_carousel":
			count = Math.round(numberInRange(settings.limit, 10, 1, 12));
			items = limitedItems(runtimeData.items, count, 12);
			return '<section class="kidia-preview-section kidia-preview-section--products">' + blockHeading(settings, name, runtimeData) + '<div class="kidia-preview-product-row" style="--kidia-preview-product-width:' + numberInRange(settings.item_width, 168, 110, 260) * 0.7 + 'px">' + (items.length ? items.map(function (product) { return renderProductCard(product, settings); }).join("") : sampleCards(Math.min(count, 3), "kidia-preview-product-card", "Product")) + "</div></section>";

		case "product_grid":
			columns = Math.round(numberInRange(settings.columns, 2, 1, 4));
			count = Math.round(numberInRange(settings.limit, 8, 1, 6));
			items = limitedItems(runtimeData.items, count, 6);
			return '<section class="kidia-preview-section kidia-preview-section--products">' + blockHeading(settings, name, runtimeData) + '<div class="kidia-preview-product-grid" style="--kidia-preview-columns:' + columns + '">' + (items.length ? items.map(function (product) { return renderProductCard(product, settings); }).join("") : sampleCards(count, "kidia-preview-product-card", "Product")) + "</div></section>";

		case "section_header":
			return '<div class="kidia-preview-section-heading kidia-preview-section-heading--standalone"><div><strong>' + escapeHtml(settings.title || name) + "</strong>" + (settings.subtitle ? "<small>" + escapeHtml(settings.subtitle) + "</small>" : "") + "</div>" + (settings.show_view_all === "" ? "" : "<span>" + escapeHtml(settings.view_all_label || "View all") + " ‹</span>") + "</div>";

		case "brand_carousel":
			count = Math.round(numberInRange(settings.limit, 12, 1, 5));
			items = limitedItems(runtimeData.items, count, 5);
			return '<section class="kidia-preview-section">' + blockHeading(settings, name, runtimeData) + '<div class="kidia-preview-brand-row' + (settings.layout === "grid" ? " is-grid" : "") + '" style="--kidia-preview-columns:' + numberInRange(settings.columns, 4, 2, 6) + ";gap:" + numberInRange(settings.gap, 12, 0, 32) * 0.55 + 'px">' + (items.length ? items.map(function (brand) { return renderBrandCard(brand, runtimeData.item_width || settings.item_width, settings); }).join("") : sampleCards(count, "kidia-preview-brand-card", "Brand")) + "</div></section>";

		case "quick_links":
			items = Array.isArray(settings.items) ? settings.items : [];
			columns = Math.round(numberInRange(settings.columns, 4, 2, 6));
			return '<section class="kidia-preview-section">' + blockHeading(settings, name, runtimeData) + '<div class="kidia-preview-quick-links ' + (settings.layout === "grid" ? "is-grid" : "is-row") + '" style="--kidia-preview-columns:' + columns + ";gap:" + numberInRange(settings.gap, 12, 0, 32) * 0.55 + 'px">' + (items.length ? items.map(function (link) { return renderQuickLink(link, settings); }).join("") : sampleCards(columns, "kidia-preview-quick-link", "Link")) + "</div></section>";

		case "banner_grid":
			items = Array.isArray(settings.items) ? settings.items : [];
			columns = Math.round(numberInRange(settings.columns, 2, 1, 3));
			return '<section class="kidia-preview-section">' + blockHeading(settings, name, runtimeData) + '<div class="kidia-preview-banner-grid is-' + escapeHtml(settings.layout || "equal") + '" style="--kidia-preview-columns:' + columns + ";gap:" + numberInRange(settings.gap, 10, 0, 32) * 0.55 + 'px">' + (items.length ? items.map(function (banner) { return renderBannerTile(banner, settings); }).join("") : sampleCards(columns + 1, "kidia-preview-banner-tile", "")) + "</div></section>";

		case "promo_strip":
			background = safeColor(settings.background_color, "#4f9f8f");
			textColor = safeColor(settings.text_color, "#ffffff");
			return '<div class="kidia-preview-promo" style="background:' + background + ";color:" + textColor + '"><span>✦</span><strong>' + escapeHtml(settings.text || name) + "</strong></div>";

		case "coupon_banner":
			image = safeImage(settings.image_url);
			return '<div class="kidia-preview-coupon' + (image ? " has-image" : "") + '" style="background:' + safeColor(settings.background_color, "#DCEEE8") + ";color:" + safeColor(settings.text_color, "#1F2933") + ";border-radius:" + numberInRange(settings.border_radius, 20, 0, 48) * 0.65 + 'px">' + (image ? '<img src="' + image + '" alt="">' : "") + '<div class="kidia-preview-coupon__overlay"><strong>' + escapeHtml(settings.title || name) + "</strong><small>" + escapeHtml(settings.description || "") + "</small>" + (settings.coupon_code ? '<code style="color:' + safeColor(settings.accent_color, "#2F806E") + '">▣ ' + escapeHtml(settings.coupon_code) + "</code>" : "") + "</div></div>";

		case "countdown":
			return '<div class="kidia-preview-countdown" style="background:' + safeColor(settings.background_color, "#FFFFFF") + ";color:" + safeColor(settings.text_color, "#1F2933") + '"><strong>' + escapeHtml(settings.title || name) + '</strong><div style="--kidia-countdown-box:' + safeColor(settings.box_color, "#E9EEEC") + '"><span>02<small>يوم</small></span><span>14<small>ساعة</small></span><span>37<small>دقيقة</small></span><span>42<small>ثانية</small></span></div></div>';

		case "video_banner":
			image = safeImage(settings.poster_url);
			ratio = numberInRange(settings.aspect_ratio, 1.8, 0.45, 4);
			return '<div class="kidia-preview-block kidia-preview-video" style="aspect-ratio:' + ratio + '">' + (image ? '<img src="' + image + '" alt="">' : '<div class="kidia-preview-placeholder">' + name + "</div>") + '<span class="kidia-preview-video__play">▶</span></div>';

		case "text_block":
			background = safeColor(settings.background, "#ffffff");
			textColor = safeColor(settings.text_color, "#111111");
			return '<div class="kidia-preview-text" style="background:' + background + ";color:" + textColor + ";text-align:" + (settings.alignment === "left" || settings.alignment === "center" ? settings.alignment : "right") + ";font-weight:" + (settings.font_weight === "bold" ? "700" : settings.font_weight === "medium" ? "500" : "400") + '"><strong style="font-size:' + numberInRange(settings.title_size, 22, 12, 48) * 0.58 + 'px">' + escapeHtml(settings.title || name) + '</strong><p style="font-size:' + numberInRange(settings.content_size, 15, 10, 32) * 0.62 + 'px">' + escapeHtml(settings.content || "") + "</p></div>";

		case "divider":
			return '<div class="kidia-preview-divider" style="margin-block:' + numberInRange(settings.margin, 16, 0, 64) + "px;border-top:" + numberInRange(settings.thickness, 1, 1, 12) + "px solid " + safeColor(settings.color, "#e5e7eb") + '"></div>';

		case "spacer":
			return '<div class="kidia-preview-spacer" style="height:' + numberInRange(settings.height, 24, 0, 160) + 'px"><span>' + numberInRange(settings.height, 24, 0, 160) + "px</span></div>";

		default:
			return '<div class="kidia-preview-block"><div class="kidia-preview-block__label">' + name + '</div><div class="kidia-preview-placeholder">' + escapeHtml(replaceEvery(block.type, "_", " ")) + "</div></div>";
		}
	}

	function renderPreview() {
		var blocks;

		if (!previewContent) {
			return;
		}

		blocks = serializeBlocks().filter(function (block) {
			return Boolean(block.enabled);
		});

		if (!blocks.length) {
			previewContent.innerHTML = '<div class="kidia-preview-empty">Add or enable an element to preview the Home Page.</div>';
			return;
		}

		previewContent.innerHTML = blocks.map(renderBlock).join("");
	}

	function loadRuntimePreview() {
		if (Array.isArray(config.previewBlocks)) {
			registerPreviewBlocks(config.previewBlocks);
		}

		if (!config.previewEndpoint || typeof window.fetch !== "function") {
			return;
		}

		window.fetch(String(config.previewEndpoint), {
			credentials: "same-origin",
			cache: "no-store"
		}).then(function (response) {
			if (!response.ok) {
				throw new Error("Home preview request failed with HTTP " + response.status + ".");
			}
			return response.json();
		}).then(function (payload) {
			if (!payload || !Array.isArray(payload.blocks)) {
				throw new Error("Home preview response did not contain blocks.");
			}
			registerPreviewBlocks(payload.blocks);
			renderPreview();
		}).catch(function (error) {
			if (window.console && window.console.warn) {
				window.console.warn("Kidia Home preview kept its local fallback because runtime data could not be loaded.", error);
			}
		});
	}

	function setCollapsed(block, collapsed) {
		var toggle;

		block.classList.toggle("is-collapsed", collapsed);
		toggle = block.querySelector(".kidia-toggle-block-settings");
		if (toggle) {
			toggle.setAttribute("aria-expanded", collapsed ? "false" : "true");
		}
	}

	function collapseAll(collapsed) {
		getBlocks().forEach(function (block) {
			setCollapsed(block, collapsed);
		});
	}

	function openPicker() {
		if (!picker) {
			return;
		}

		picker.hidden = false;
		picker.setAttribute("aria-hidden", "false");
		document.body.classList.add("kidia-picker-open");
		window.setTimeout(function () {
			if (searchInput) {
				searchInput.focus();
			}
		}, 40);
	}

	function closePicker() {
		if (!picker) {
			return;
		}

		picker.hidden = true;
		picker.setAttribute("aria-hidden", "true");
		document.body.classList.remove("kidia-picker-open");
	}

	function openCreateModal(type, label) {
		if (!createModal) {
			return;
		}

		currentCreateType = type;
		if (createTitle) {
			createTitle.textContent = (labels.createPrefix || "Create") + " " + label;
		}
		if (createNameInput) {
			createNameInput.value = "";
		}
		if (createError) {
			createError.hidden = true;
		}

		createModal.hidden = false;
		createModal.setAttribute("aria-hidden", "false");
		document.body.classList.add("kidia-modal-open");
		window.setTimeout(function () {
			if (createNameInput) {
				createNameInput.focus();
			}
		}, 40);
	}

	function closeCreateModal() {
		if (!createModal) {
			return;
		}

		createModal.hidden = true;
		createModal.setAttribute("aria-hidden", "true");
		document.body.classList.remove("kidia-modal-open");
		currentCreateType = "";
	}

	function removeEmptyState() {
		var empty = document.getElementById("kidia-builder-empty");
		if (empty) {
			empty.remove();
		}
	}

	function ensureEmptyState() {
		var empty;

		if (getBlocks().length || document.getElementById("kidia-builder-empty")) {
			return;
		}

		empty = document.createElement("div");
		empty.id = "kidia-builder-empty";
		empty.className = "kidia-builder-empty";
		empty.innerHTML = '<span class="dashicons dashicons-screenoptions"></span><h2></h2><p></p><button type="button" class="button button-primary" data-kidia-open-picker></button>';
		empty.querySelector("h2").textContent = labels.noElements || "No elements";
		empty.querySelector("p").textContent = labels.noElementsDescription || "Add an element to build the Home Page.";
		empty.querySelector("button").textContent = labels.addFirst || "Add First Element";
		builder.appendChild(empty);
	}

	function findBlockByReference(type, libraryId) {
		var blocks = getBlocks();
		var index;

		for (index = 0; index < blocks.length; index += 1) {
			if (blocks[index].dataset.type === type && blocks[index].dataset.libraryId === libraryId) {
				return blocks[index];
			}
		}

		return null;
	}

	function appendTemplate(templateId, type, libraryId, name, isNew) {
		var template = document.getElementById(templateId);
		var existing;
		var index;
		var blockId;
		var resolvedLibraryId;
		var html;
		var blocks;
		var block;
		var nameInput;
		var nameLabel;
		var createIntentInput;

		if (!template) {
			return null;
		}

		existing = findBlockByReference(type, libraryId);
		if (existing) {
			closePicker();
			existing.scrollIntoView({ behavior: "smooth", block: "center" });
			existing.classList.add("is-highlighted");
			window.setTimeout(function () {
				existing.classList.remove("is-highlighted");
			}, 1000);
			return existing;
		}

		index = getBlocks().length;
		blockId = generateId(type);
		resolvedLibraryId = libraryId || blockId;
		html = template.innerHTML;
		html = replaceEvery(html, "__INDEX__", String(index));
		html = replaceEvery(html, "987654321", String(index));
		html = replaceEvery(html, "__ORDER__", String(index + 1));
		html = replaceEvery(html, "__BLOCK_ID__", blockId);
		html = replaceEvery(html, "__LIBRARY_ID__", resolvedLibraryId);
		html = replaceEvery(html, "__BLOCK_NAME__", "");

		removeEmptyState();
		builder.insertAdjacentHTML("beforeend", html);
		blocks = getBlocks();
		block = blocks.length ? blocks[blocks.length - 1] : null;

		if (block) {
			nameInput = block.querySelector(".kidia-block-name-input");
			nameLabel = block.querySelector(".kidia-block-name");
			createIntentInput = block.querySelector(".kidia-block-create-intent");

			if (nameInput) {
				nameInput.value = name || "";
			}
			if (nameLabel) {
				nameLabel.textContent = name || labels.untitled || "Untitled Element";
			}
			if (createIntentInput) {
				createIntentInput.value = isNew ? "1" : "0";
			}

			block.dataset.isNew = isNew ? "true" : "false";
			block.draggable = false;
			setCollapsed(block, false);
			block.scrollIntoView({ behavior: "smooth", block: "center" });
		}

		updateIndexes();
		markDirty();
		renderPreview();
		closePicker();
		return block;
	}

	function createElement() {
		var name = createNameInput ? createNameInput.value.trim() : "";
		var type;
		var libraryId;

		if (!name) {
			if (createError) {
				createError.hidden = false;
			}
			return;
		}

		if (!currentCreateType) {
			return;
		}

		type = currentCreateType;
		libraryId = generateId(type);
		appendTemplate("tmpl-kidia-block-" + type, type, libraryId, name, true);
		closeCreateModal();
	}

	function setDraftStatus(block) {
		var statusInput = block.querySelector(".kidia-block-status");
		var statusSelect = block.querySelector(".kidia-block-status-select");
		var statusBadge = block.querySelector(".kidia-builder-status");

		if (statusInput) {
			statusInput.value = "draft";
		}
		if (statusSelect) {
			statusSelect.value = "draft";
		}
		if (statusBadge) {
			statusBadge.classList.remove("kidia-builder-status--published");
			statusBadge.classList.add("kidia-builder-status--draft");
			statusBadge.textContent = labels.draft || "Draft";
		}
	}

	function duplicateBlock(block) {
		var clone = block.cloneNode(true);
		var typeField = clone.querySelector(".kidia-block-type");
		var type = typeField ? typeField.value : "block";
		var newId = generateId(type);
		var idInput = clone.querySelector(".kidia-block-id");
		var libraryInput = clone.querySelector(".kidia-block-library-id");
		var sourceLibraryInput = clone.querySelector(".kidia-block-source-library-id");
		var createIntentInput = clone.querySelector(".kidia-block-create-intent");
		var editButton = clone.querySelector(".kidia-edit-library-item");
		var nameInput = clone.querySelector(".kidia-block-name-input");
		var nameLabel = clone.querySelector(".kidia-block-name");

		if (idInput) {
			idInput.value = newId;
		}
		if (libraryInput) {
			if (sourceLibraryInput) {
				sourceLibraryInput.value = sourceLibraryInput.value || libraryInput.value;
			}
			libraryInput.value = newId;
		}
		if (editButton) {
			editButton.dataset.libraryId = newId;
		}
		if (createIntentInput) {
			createIntentInput.value = "1";
		}
		if (nameInput) {
			nameInput.value += labels.copySuffix || " Copy";
			if (nameLabel) {
				nameLabel.textContent = nameInput.value;
			}
		}

		clone.dataset.libraryId = newId;
		clone.dataset.isNew = "true";
		clone.draggable = false;
		setDraftStatus(clone);
		setCollapsed(clone, true);
		block.insertAdjacentElement("afterend", clone);
		updateIndexes();
		markDirty();
		renderPreview();
		clone.scrollIntoView({ behavior: "smooth", block: "center" });
	}

	function reindexHeroItems(block) {
		var items = block.querySelectorAll(".kidia-hero-block-item");
		toArray(items).forEach(function (item, itemIndex) {
			toArray(item.querySelectorAll('[name*="[settings][items]"]')).forEach(function (input) {
				input.name = input.name.replace(/(\[settings\]\[items\])\[[^\]]*\]/, "$1[" + itemIndex + "]");
			});
		});
	}

	function reindexRepeatableItems(block) {
		var items = block.querySelectorAll(".kidia-repeatable-item");
		toArray(items).forEach(function (item, itemIndex) {
			toArray(item.querySelectorAll('[name*="[settings][items]"]')).forEach(function (input) {
				input.name = input.name.replace(/(\[settings\]\[items\])\[[^\]]*\]/, "$1[" + itemIndex + "]");
			});
		});
	}

	function addRepeatableItem(block) {
		var container = block.querySelector(".kidia-repeatable-items");
		var template = block.querySelector(".tmpl-kidia-repeatable-item");
		var itemIndex;
		var html;
		if (!container || !template) { return; }
		itemIndex = container.querySelectorAll(".kidia-repeatable-item").length;
		html = replaceEvery(template.innerHTML, "__ITEM_INDEX__", String(itemIndex));
		container.insertAdjacentHTML("beforeend", html);
		reindexRepeatableItems(block);
		markDirty();
		renderPreview();
	}

	function addHeroSlide(block) {
		var container = block.querySelector(".kidia-hero-block-items");
		var template = block.querySelector(".tmpl-kidia-hero-block-item");
		var itemIndex;
		var html;

		if (!container || !template) {
			return;
		}

		itemIndex = container.querySelectorAll(".kidia-hero-block-item").length;
		html = replaceEvery(template.innerHTML, "__ITEM_INDEX__", String(itemIndex));
		container.insertAdjacentHTML("beforeend", html);
		reindexHeroItems(block);
		markDirty();
		renderPreview();
	}

	function openMediaPicker(options, onSelect) {
		var frame;

		if (!window.wp || !window.wp.media) {
			return;
		}

		frame = window.wp.media(options);
		frame.on("select", onSelect.bind(null, frame));
		frame.open();
	}

	document.addEventListener("click", function (event) {
		var target = event.target;
		var createButton;
		var libraryButton;

		if (!target || target.nodeType !== 1) {
			return;
		}

		if (target.closest("[data-kidia-open-picker]")) {
			openPicker();
			return;
		}
		if (target.closest("[data-kidia-close-picker]")) {
			closePicker();
			return;
		}
		if (target.closest("[data-kidia-close-create-modal]")) {
			closeCreateModal();
			return;
		}

		createButton = target.closest(".kidia-create-element");
		if (createButton) {
			openCreateModal(createButton.dataset.blockType || "", createButton.dataset.blockLabel || "");
			return;
		}

		libraryButton = target.closest(".kidia-add-library-element");
		if (libraryButton) {
			appendTemplate(libraryButton.dataset.templateId || "", libraryButton.dataset.blockType || "", libraryButton.dataset.libraryId || "", libraryButton.dataset.blockName || "", false);
		}
	});

	var addElement = document.getElementById("kidia-add-element");
	var collapseButton = document.getElementById("kidia-collapse-all");
	var expandButton = document.getElementById("kidia-expand-all");
	var createSubmit = document.getElementById("kidia-create-element-submit");

	if (addElement) {
		addElement.addEventListener("click", openPicker);
	}
	if (collapseButton) {
		collapseButton.addEventListener("click", function () { collapseAll(true); });
	}
	if (expandButton) {
		expandButton.addEventListener("click", function () { collapseAll(false); });
	}
	if (createSubmit) {
		createSubmit.addEventListener("click", createElement);
	}
	if (createNameInput) {
		createNameInput.addEventListener("keydown", function (event) {
			if (event.key === "Enter") {
				event.preventDefault();
				createElement();
			}
		});
	}

	builder.addEventListener("click", function (event) {
		var target = event.target;
		var block;
		var action;
		var name;
		var message;
		var item;

		if (!target || target.nodeType !== 1) {
			return;
		}

		block = target.closest(".kidia-builder-block");
		if (!block) {
			return;
		}

		if (target.closest(".kidia-toggle-block-settings")) {
			setCollapsed(block, !block.classList.contains("is-collapsed"));
			return;
		}

		if (target.closest(".kidia-delete-block")) {
			name = block.querySelector(".kidia-block-name");
			name = name ? name.textContent.trim() : labels.untitled || "Untitled Element";
			message = labels.deleteConfirm || "Remove this element from the Home page?";
			if (!window.confirm(message + "\n" + name)) {
				return;
			}
			block.remove();
			updateIndexes();
			ensureEmptyState();
			markDirty();
			renderPreview();
			return;
		}

		if (target.closest(".kidia-duplicate-block")) {
			duplicateBlock(block);
			return;
		}

		if (target.closest(".kidia-add-hero-block-item")) {
			addHeroSlide(block);
			return;
		}

		if (target.closest(".kidia-add-repeatable-item")) {
			addRepeatableItem(block);
			return;
		}

		if (target.closest(".kidia-remove-repeatable-item")) {
			item = target.closest(".kidia-repeatable-item");
			if (item) {
				item.remove();
				reindexRepeatableItems(block);
				markDirty();
				renderPreview();
			}
			return;
		}

		if (target.closest(".kidia-remove-hero-block-item")) {
			item = target.closest(".kidia-hero-block-item");
			if (item) {
				item.remove();
				reindexHeroItems(block);
				markDirty();
				renderPreview();
			}
			return;
		}

		if (target.closest(".kidia-select-hero-block-image, .kidia-hero-block-image-preview")) {
			item = target.closest(".kidia-hero-block-item");
			openMediaPicker({ title: "Choose slide image", button: { text: "Use image" }, multiple: false }, function (frame) {
				var selection = frame.state().get("selection").first();
				var attachment = selection ? selection.toJSON() : null;
				var input = item ? item.querySelector(".kidia-hero-block-image-url") : null;
				var preview = item ? item.querySelector(".kidia-hero-block-image-preview") : null;
				if (!attachment || !attachment.url) {
					return;
				}
				if (input) {
					input.value = attachment.url;
				}
				if (preview) {
					preview.src = attachment.url;
					preview.hidden = false;
					preview.style.display = "";
				}
				markDirty();
				renderPreview();
			});
			return;
		}

		action = target.closest(".kidia-select-banner-image, .kidia-select-media, .kidia-select-app-header-logo, .kidia-banner-image-preview, .kidia-media-preview");
		if (action) {
			openMediaPicker({ title: "Choose image", button: { text: "Use image" }, multiple: false }, function (frame) {
				var selection = frame.state().get("selection").first();
				var attachment = selection ? selection.toJSON() : null;
				var field = action.closest(".kidia-builder-field");
				var input = field ? field.querySelector(".kidia-banner-image-url, .kidia-media-url, .kidia-app-header-logo-url") : null;
				var preview = field ? field.querySelector(".kidia-banner-image-preview, .kidia-media-preview") : null;
				if (!attachment || !attachment.url) {
					return;
				}
				if (input) {
					input.value = attachment.url;
				}
				if (preview) {
					preview.src = attachment.url;
					preview.hidden = false;
					preview.style.display = "";
				}
				markDirty();
				renderPreview();
			});
		}
	});

	builder.addEventListener("change", function (event) {
		var target = event.target;
		var block;
		var hidden;
		var badge;

		if (!target || target.nodeType !== 1) {
			return;
		}

		if (target.classList.contains("kidia-block-status-select")) {
			block = target.closest(".kidia-builder-block");
			hidden = block ? block.querySelector(".kidia-block-status") : null;
			badge = block ? block.querySelector(".kidia-builder-status") : null;
			if (hidden) {
				hidden.value = target.value;
			}
			if (badge) {
				badge.textContent = target.value === "published" ? labels.published || "Published" : labels.draft || "Draft";
				badge.className = "kidia-builder-status kidia-builder-status--" + target.value;
			}
		}

		markDirty();
		renderPreview();
	});

	builder.addEventListener("input", function (event) {
		var target = event.target;
		var block;
		var name;

		if (!target || target.nodeType !== 1) {
			return;
		}

		if (target.classList.contains("kidia-block-name-input")) {
			block = target.closest(".kidia-builder-block");
			name = block ? block.querySelector(".kidia-block-name") : null;
			if (name) {
				name.textContent = target.value.trim() || labels.untitled || "Untitled Element";
			}
		}

		markDirty();
		renderPreview();
	});

	builder.addEventListener("pointerdown", function (event) {
		var target = event.target;
		var handle;
		var block;

		if (!target || target.nodeType !== 1) {
			return;
		}

		handle = target.closest(".kidia-builder-drag");
		block = handle ? handle.closest(".kidia-builder-block") : null;
		if (block) {
			block.draggable = true;
		}
	});

	builder.addEventListener("dragstart", function (event) {
		var target = event.target;
		var block;

		if (!target || target.nodeType !== 1) {
			return;
		}

		block = target.closest(".kidia-builder-block");
		if (!block || !block.draggable) {
			event.preventDefault();
			return;
		}

		draggedBlock = block;
		block.classList.add("is-dragging");
		if (event.dataTransfer) {
			event.dataTransfer.effectAllowed = "move";
			event.dataTransfer.setData("text/plain", block.dataset.libraryId || "");
		}
	});

	builder.addEventListener("dragover", function (event) {
		var target = event.target;
		var targetBlock;
		var rect;
		var after;

		if (!draggedBlock) {
			return;
		}

		event.preventDefault();
		if (!target || target.nodeType !== 1) {
			return;
		}

		targetBlock = target.closest(".kidia-builder-block");
		if (!targetBlock || targetBlock === draggedBlock) {
			return;
		}

		rect = targetBlock.getBoundingClientRect();
		after = event.clientY > rect.top + rect.height / 2;
		targetBlock.insertAdjacentElement(after ? "afterend" : "beforebegin", draggedBlock);
	});

	builder.addEventListener("dragend", function () {
		if (draggedBlock) {
			draggedBlock.classList.remove("is-dragging");
			draggedBlock.draggable = false;
		}
		draggedBlock = null;
		updateIndexes();
		markDirty();
		renderPreview();
	});

	if (searchInput) {
		searchInput.addEventListener("input", function () {
			var value = searchInput.value.trim().toLocaleLowerCase();
			var visibleGroups = 0;
			var noResults;

			toArray(document.querySelectorAll(".kidia-element-group")).forEach(function (group) {
				var matches = group.textContent.toLocaleLowerCase().indexOf(value) !== -1;
				group.hidden = !matches;
				visibleGroups += matches ? 1 : 0;
			});

			noResults = document.getElementById("kidia-element-picker-no-results");
			if (noResults) {
				noResults.hidden = visibleGroups !== 0;
			}
		});
	}

	document.addEventListener("keydown", function (event) {
		if (event.key === "Escape") {
			closePicker();
			closeCreateModal();
		}
	});

	form.addEventListener("submit", function () {
		updateIndexes();
		if (blocksPayload) {
			blocksPayload.value = JSON.stringify(serializeBlocks());
		}
		isDirty = false;
	});

	window.addEventListener("beforeunload", function (event) {
		if (!isDirty) {
			return;
		}
		event.preventDefault();
		event.returnValue = "";
	});

	getBlocks().forEach(function (block) {
		block.draggable = false;
		setCollapsed(block, true);
	});
	updateIndexes();
	loadRuntimePreview();
	renderPreview();
}());
