(function () {
	"use strict";
	document.addEventListener("DOMContentLoaded", function () {
		var form = document.querySelector(".kidia-commerce-preview-form");
		var preview = document.getElementById("kidia-commerce-preview");
		var config = window.kidiaCommercePreview || {};
		if (!form || !preview) { return; }
		function escapeHtml(value) { var node = document.createElement("div"); node.textContent = value == null ? "" : String(value); return node.innerHTML; }
		function field(key) { return form.querySelector('[name$="[' + key + ']\"]:not([type="hidden"])'); }
		function value(key, fallback) { var input = field(key); return input && input.value !== "" ? input.value : fallback; }
		function checked(key, fallback) { var input = field(key); return input ? input.checked : fallback; }
		function number(key, fallback) { var parsed = parseFloat(value(key, fallback)); return isFinite(parsed) ? parsed : fallback; }
		function card(product, checkout) {
			var image = product.image_url ? '<img src="' + escapeHtml(product.image_url) + '" alt="">' : '<span class="dashicons dashicons-products"></span>';
			return '<article class="kidia-app-product kidia-commerce-card is-' + escapeHtml(value("card_style", "outlined")) + '"><div class="kidia-app-product__image">' + image + '</div><div class="kidia-app-product__copy"><strong>' + escapeHtml(product.name || "Kidia product") + '</strong>' + (checked("show_rating", false) ? '<span class="kidia-app-rating">★★★★★</span>' : '') + (checked("show_price", true) ? '<b>' + escapeHtml(product.price || "EGP 0") + '</b>' : '') + (checkout ? '<button type="button" tabindex="-1">' + escapeHtml(value("button_label", "Add")) + '</button>' : '') + '</div></article>';
		}
		function draw() {
			var enabled = checked("enabled", true), checkout = preview.getAttribute("data-preview-kind") === "checkout";
			var columns = Math.max(1, Math.min(3, number("columns", 2))), radius = Math.max(0, number("card_radius", 14)), ratio = Math.max(0.5, number("image_ratio", 1));
			var rows = (Array.isArray(config.products) ? config.products : []).slice(0, Math.max(1, Math.min(8, number("limit", 6))));
			var cards = rows.length ? rows.map(function (product) { return card(product, checkout); }).join("") : card({}, checkout) + card({}, checkout);
			preview.innerHTML = '<div class="kidia-app-status">9:41 <span>● ◒ ▰</span></div><header class="kidia-app-header"><span class="dashicons dashicons-arrow-left-alt2"></span><strong>' + (checkout ? 'Checkout' : 'Product details') + '</strong><span class="dashicons dashicons-cart"></span></header><main class="kidia-commerce-screen"><section class="kidia-commerce-context">' + (checkout ? '<strong>Order summary</strong><span>Delivery address and payment</span>' : '<div class="kidia-commerce-product-photo"><span class="dashicons dashicons-format-image"></span></div><strong>Kidia product</strong><span>EGP 499</span>') + '</section>' + (enabled ? '<section class="kidia-app-section kidia-commerce-section"><h3>' + escapeHtml(value("title", checkout ? "You may also need" : "You may also like")) + '</h3><div class="kidia-app-product-grid">' + cards + '</div></section>' : '') + (checkout ? '<button class="kidia-commerce-checkout" type="button">Place order</button>' : '') + '</main>';
			preview.style.setProperty("--commerce-columns", String(columns)); preview.style.setProperty("--commerce-radius", radius + "px"); preview.style.setProperty("--commerce-ratio", String(ratio)); preview.style.setProperty("--commerce-button", value("button_color", "#2F806E")); preview.style.setProperty("--commerce-button-text", value("button_text_color", "#FFFFFF"));
		}
		var queued = false; function scheduleDraw() { if (queued) { return; } queued = true; (window.requestAnimationFrame || function (callback) { callback(); })(function () { queued = false; draw(); }); }
		form.addEventListener("input", scheduleDraw); form.addEventListener("change", scheduleDraw); draw();
	});
}());
