(function () {
	"use strict";
	document.addEventListener("DOMContentLoaded", function () {
		var form = document.querySelector(".mobishop-commerce-preview-form");
		var preview = document.getElementById("mobishop-commerce-preview");
		var config = window.mobishopCommercePreview || {};
		if (!form || !preview) { return; }
		function escapeHtml(value) { var node = document.createElement("div"); node.textContent = value == null ? "" : String(value); return node.innerHTML; }
		function field(key) { return form.querySelector('[name="suggestions[' + key + ']"]:not([type="hidden"])'); }
		function value(key, fallback) { var input = field(key); return input && input.value !== "" ? input.value : fallback; }
		function checked(key, fallback) { var input = field(key); return input ? input.checked : fallback; }
		function number(key, fallback) { var parsed = parseFloat(value(key, fallback)); return isFinite(parsed) ? parsed : fallback; }
		function checkoutDesign() {
			var selected = form.querySelector('[name="checkout_design"]:checked');
			return selected && /^(classic|summary_first|compact)$/.test(selected.value) ? selected.value : "classic";
		}
		function card(product, checkout) {
			var image = product.image_url ? '<img src="' + escapeHtml(product.image_url) + '" alt="">' : '<span class="dashicons dashicons-products"></span>';
			return '<article class="mobishop-app-product mobishop-commerce-card is-' + escapeHtml(value("card_style", "outlined")) + '"><div class="mobishop-app-product__image">' + image + '</div><div class="mobishop-app-product__copy"><strong>' + escapeHtml(product.name || "MobiShop product") + '</strong>' + (checked("show_rating", false) ? '<span class="mobishop-app-rating">★★★★★</span>' : '') + (checked("show_price", true) ? '<b>' + escapeHtml(product.price || "EGP 0") + '</b>' : '') + (checkout ? '<button type="button" tabindex="-1">' + escapeHtml(value("button_label", "Add")) + '</button>' : '') + '</div></article>';
		}
		function checkoutFields() {
			var pageEnabled = form.querySelector('[name="checkout[enabled]"]:not([type="hidden"])');
			if (pageEnabled && !pageEnabled.checked) return '<section class="mobishop-commerce-fields is-disabled"><strong>Checkout fields are disabled</strong></section>';
			var groups = { billing: [], shipping: [], order: [] };
			form.querySelectorAll("[data-checkout-field]").forEach(function (row) {
				var enabled = row.querySelector('[name$="[enabled]"]:not([type="hidden"])');
				var type = row.querySelector('[name$="[type]"]');
				if ((enabled && !enabled.checked) || (type && type.value === "hidden")) return;
				var group = row.querySelector('[name$="[group]"]');
				var label = row.querySelector('[name$="[label]"]');
				var placeholder = row.querySelector('[name$="[placeholder]"]');
				var required = row.querySelector('[name$="[required]"]:not([type="hidden"])');
				var groupKey = group && groups[group.value] ? group.value : "billing";
				var labelText = label && label.value ? label.value : "Checkout field";
				var mark = required && required.checked ? " *" : "";
				var control = type && type.value === "textarea"
					? '<div class="mobishop-commerce-preview-input is-textarea">' + escapeHtml(placeholder && placeholder.value ? placeholder.value : labelText) + '</div>'
					: type && type.value === "checkbox"
						? '<div class="mobishop-commerce-preview-check"><i></i>' + escapeHtml(labelText + mark) + '</div>'
						: '<div class="mobishop-commerce-preview-input">' + escapeHtml(labelText + mark) + '</div>';
				groups[groupKey].push(control);
			});
			var labels = { billing: "Billing details", shipping: "Shipping details", order: "Order details" };
			return Object.keys(groups).map(function (group) {
				return groups[group].length ? '<section class="mobishop-commerce-fields"><strong>' + labels[group] + '</strong>' + groups[group].join("") + '</section>' : "";
			}).join("");
		}
		function draw() {
			var enabled = checked("enabled", true), checkout = preview.getAttribute("data-preview-kind") === "checkout";
			var columns = Math.max(1, Math.min(3, number("columns", 2))), radius = Math.max(0, number("card_radius", 14)), ratio = Math.max(0.5, number("image_ratio", 1));
			var rows = (Array.isArray(config.products) ? config.products : []).slice(0, Math.max(1, Math.min(8, number("limit", 6))));
			var cards = rows.length ? rows.map(function (product) { return card(product, checkout); }).join("") : card({}, checkout) + card({}, checkout);
			var design = checkoutDesign();
			var checkoutContent = '<section class="mobishop-commerce-context"><strong>Order summary</strong><span>2 items · Delivery and payment</span></section>' + checkoutFields() + '<button class="mobishop-commerce-checkout" type="button">Place order</button>';
			var relatedContent = '<section class="mobishop-commerce-context"><div class="mobishop-commerce-product-photo"><span class="dashicons dashicons-format-image"></span></div><strong>MobiShop product</strong><span>EGP 499</span></section>' + (enabled ? '<section class="mobishop-app-section mobishop-commerce-section"><h3>' + escapeHtml(value("title", "You may also like")) + '</h3><div class="mobishop-app-product-grid">' + cards + '</div></section>' : '');
			preview.innerHTML = '<div class="mobishop-app-status">9:41 <span>● ◒ ▰</span></div><header class="mobishop-app-header"><span class="dashicons dashicons-arrow-left-alt2"></span><strong>' + (checkout ? 'Checkout' : 'Product details') + '</strong><span class="dashicons dashicons-cart"></span></header><main class="mobishop-commerce-screen' + (checkout ? ' is-checkout-' + design : '') + '">' + (checkout ? checkoutContent : relatedContent) + '</main>';
			preview.style.setProperty("--commerce-columns", String(columns)); preview.style.setProperty("--commerce-radius", radius + "px"); preview.style.setProperty("--commerce-ratio", String(ratio)); preview.style.setProperty("--commerce-button", value("button_color", "#2F806E")); preview.style.setProperty("--commerce-button-text", value("button_text_color", "#FFFFFF"));
		}
		var queued = false; function scheduleDraw() { if (queued) { return; } queued = true; (window.requestAnimationFrame || function (callback) { callback(); })(function () { queued = false; draw(); }); }
		form.addEventListener("input", scheduleDraw); form.addEventListener("change", scheduleDraw); draw();
	});
}());
