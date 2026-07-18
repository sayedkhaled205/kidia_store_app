(function ($) {
	"use strict";
	var root = document.querySelector(".kidia-page-builder");
	if (!root) { return; }
	var list = document.getElementById("kidia-page-elements");
	var preview = document.getElementById("kidia-page-live-preview");
	var dragged = null;
	var config = window.kidiaPageBuilder || {};
	var products = Array.isArray(config.products) ? config.products : [];

	function array(value) { return Array.prototype.slice.call(value || []); }
	function escapeHtml(value) { return String(value || "").replace(/[&<>"']/g, function (c) { return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"}[c]; }); }
	function field(scope, suffix) { var items = scope.querySelectorAll('[name$="[' + suffix + ']"]'); return items.length ? items[items.length - 1] : null; }
	function value(scope, suffix, fallback) { var item = field(scope, suffix); return item ? item.value : fallback; }
	function checked(scope, suffix, fallback) { var item = field(scope, suffix); return item ? item.checked : fallback; }
	function color(scope, suffix, fallback) { var result = value(scope, suffix, fallback); return /^#[0-9a-f]{6}$/i.test(result) ? result : fallback; }
	function number(scope, suffix, fallback) { var result = Number(value(scope, suffix, fallback)); return isFinite(result) ? result : fallback; }
	function productCards(columns, limit) {
		var items = products.slice(0, Math.max(columns, Math.min(limit || 4, 6)));
		if (!items.length) {
			items = [
				{name:"Kidia product",price:"450",image_url:""},
				{name:"New collection",price:"390",image_url:""},
				{name:"Kids outfit",price:"320",image_url:""}
			];
		}
		return '<div class="kidia-page-preview-products" style="--columns:' + columns + '">' + items.map(function (item) {
			var image = item.image_url ? '<img src="' + escapeHtml(item.image_url) + '" alt="">' : '<div class="kidia-page-preview-avatar">K</div>';
			return '<article class="kidia-page-preview-product">' + image + '<div><strong>' + escapeHtml(item.name) + '</strong><b>' + escapeHtml(item.price || "") + '</b></div></article>';
		}).join("") + '</div>';
	}

	function updateIndexes() {
		array(list.querySelectorAll(".kidia-page-card")).forEach(function (card, index) {
			array(card.querySelectorAll("[name]")).forEach(function (input) {
				if (/^layout\[elements\]\[[^\]]+\]/.test(input.name)) {
					input.name = input.name.replace(/layout\[elements\]\[[^\]]+\]/, "layout[elements][" + index + "]");
				}
			});
		});
	}

	function previewElement(card) {
		var id = card.dataset.element || "element";
		var labels = {
			page_title:"Page title", search_bar:"Search", filter_bar:"Filter · Sort", product_grid:"Products",
			pagination:"Load more", image_gallery:"Product images", product_summary:"Name · Price · Rating",
			variations:"Sizes and colors", purchase_bar:"Quantity · Add to cart", description:"Description and details",
			reviews:"Customer reviews", related_products:"Related products", wishlist_grid:"Saved products",
			empty_state:"Empty wishlist", account_summary:"Customer profile", account_menu:"Orders · Addresses · Profile · Support",
			logout_button:"Sign out"
		};
		var columns = Math.max(1, Math.min(4, Math.round(number(card, "columns", 2))));
		var title = escapeHtml(value(card, "title", labels[id] || id.replace(/_/g, " ")));
		var body;
		if ({product_grid:true,related_products:true,wishlist_grid:true}[id]) {
			body = productCards(columns, number(card, "limit", 4));
		} else if (id === "image_gallery") {
			body = products.some(function (item) { return item.image_url; })
				? '<div class="kidia-page-preview-gallery">' + products.slice(0, 2).map(function (item) { return item.image_url ? '<img src="' + escapeHtml(item.image_url) + '" alt="">' : ''; }).join("") + '</div>'
				: '<div class="kidia-page-preview-gallery"><span class="kidia-page-preview-avatar">K</span><span class="kidia-page-preview-avatar">K</span></div>';
		} else if (id === "account_summary") {
			body = '<div class="kidia-page-preview-profile"><span class="kidia-page-preview-avatar">♙</span><div><strong>Customer name</strong><small>customer@example.com</small></div></div>';
		} else if (id === "account_menu") {
			body = '<div class="kidia-page-preview-menu"><span>Orders</span><span>Addresses</span><span>Profile</span><span>Support</span></div>';
		} else if (id === "logout_button" || id === "purchase_bar") {
			body = '<div class="kidia-page-preview-button">' + title + '</div>';
		} else if (id === "filter_bar") {
			body = '<div class="kidia-page-preview-menu"><span>Filter</span><span>Sort</span></div>';
		} else if (id === "empty_state") {
			body = '<div class="kidia-page-preview-profile"><span class="kidia-page-preview-avatar">♡</span><div><strong>' + title + '</strong><small>' + escapeHtml(value(card, "description", "Your wishlist is empty")) + '</small></div></div>';
		} else if (id === "product_summary") {
			body = '<div><strong>' + escapeHtml(products[0] ? products[0].name : "Product name") + '</strong><p style="color:#2f806e;font-weight:800">' + escapeHtml(products[0] ? products[0].price : "450") + '</p></div>';
		} else {
			body = '<div class="kidia-page-preview-lines"><i></i><i></i><i></i></div>';
		}
		return '<section class="kidia-page-preview-element"><strong>' + title + '</strong>' + body + '</section>';
	}

	function renderPreview() {
		var header = root.querySelector('[data-element="header"]');
		var footer = root.querySelector('[data-element="footer"]');
		var html = "";
		if (header && checked(header, "enabled", true)) {
			html += '<div class="kidia-page-preview-header" style="min-height:' + number(header, "height", 64) * .75 + 'px;background:' + color(header, "background_color", "#FFFFFF") + ';color:' + color(header, "title_color", "#1F2933") + '"><span>‹</span><strong>' + escapeHtml(value(header, "title", root.dataset.page || "Page")) + '</strong><span>⌕  ♡  ◫</span></div>';
			if (value(header, "search_style", "icon") === "bar" && checked(header, "show_search", true)) {
				html += '<div class="kidia-page-preview-search" style="height:' + number(header, "search_height", 40) * .65 + 'px;border-radius:' + number(header, "search_radius", 14) * .65 + 'px;background:' + color(header, "search_background", "#F1F3F4") + ';color:' + color(header, "search_text_color", "#5F6368") + '">⌕ ' + escapeHtml(value(header, "search_placeholder", "Search products")) + '</div>';
			}
		}
		array(list.querySelectorAll(".kidia-page-card")).forEach(function (card) {
			if (checked(card, "enabled", true)) { html += previewElement(card); }
		});
		if (footer && checked(footer, "enabled", true)) {
			html += '<div class="kidia-page-preview-footer" style="min-height:' + number(footer, "height", 72) * .72 + 'px;background:' + color(footer, "background_color", "#FFFFFF") + ';color:' + color(footer, "inactive_color", "#6B7280") + '"><span>⌂<b>Home</b></span><span>▦<b>Categories</b></span><span>♡<b>Wishlist</b></span><span>♙<b>Account</b></span></div>';
		}
		preview.innerHTML = html;
	}

	root.addEventListener("click", function (event) {
		var button = event.target.closest(".kidia-page-expand");
		var media = event.target.closest(".kidia-page-media-choose, .kidia-page-media-preview");
		if (button) {
			var card = button.closest(".kidia-page-card");
			var body = card.querySelector(".kidia-page-card__body");
			card.classList.toggle("is-open");
			body.hidden = !card.classList.contains("is-open");
			return;
		}
		if (media && window.wp && wp.media) {
			var mediaField = media.closest(".kidia-page-field--image");
			var frame = wp.media({title:"Choose image",button:{text:"Use image"},multiple:false});
			frame.on("select", function () {
				var attachment = frame.state().get("selection").first().toJSON();
				var input = mediaField.querySelector(".kidia-page-media-url");
				var image = mediaField.querySelector(".kidia-page-media-preview");
				input.value = attachment.url || "";
				image.src = attachment.url || "";
				image.hidden = !attachment.url;
				renderPreview();
			});
			frame.open();
		}
	});

	root.addEventListener("change", function (event) {
		if (event.target.type === "checkbox") {
			var toggle = event.target.closest(".kidia-page-toggle");
			if (toggle) { toggle.querySelector("b").textContent = event.target.checked ? "Visible" : "Hidden"; }
		}
		renderPreview();
	});
	root.addEventListener("input", renderPreview);

	list.addEventListener("pointerdown", function (event) {
		var handle = event.target.closest(".kidia-page-drag");
		var card = handle ? handle.closest(".kidia-page-card") : null;
		if (card) { card.draggable = true; }
	});
	list.addEventListener("dragstart", function (event) {
		var card = event.target.closest(".kidia-page-card");
		if (!card || !card.draggable) { event.preventDefault(); return; }
		dragged = card; card.classList.add("is-dragging");
	});
	list.addEventListener("dragover", function (event) {
		if (!dragged) { return; }
		event.preventDefault();
		var target = event.target.closest(".kidia-page-card");
		if (!target || target === dragged) { return; }
		var rect = target.getBoundingClientRect();
		target.insertAdjacentElement(event.clientY > rect.top + rect.height / 2 ? "afterend" : "beforebegin", dragged);
	});
	list.addEventListener("dragend", function () {
		if (dragged) { dragged.classList.remove("is-dragging"); dragged.draggable = false; }
		dragged = null; updateIndexes(); renderPreview();
	});
	root.querySelector("form").addEventListener("submit", function () {
		updateIndexes();
		var button = root.querySelector('button[type="submit"],input[type="submit"]');
		if (button) { button.disabled = true; button.setAttribute("aria-busy", "true"); }
	});
	window.addEventListener("pageshow", function () {
		var button = root.querySelector('button[type="submit"],input[type="submit"]');
		if (button) { button.disabled = false; button.removeAttribute("aria-busy"); }
	});

	if ($ && $.fn && $.fn.sortable) {
		$(list).sortable({handle:".kidia-page-drag",items:"> .kidia-page-card",update:function(){updateIndexes();renderPreview();}});
	}
	updateIndexes(); renderPreview();
}(window.jQuery));
