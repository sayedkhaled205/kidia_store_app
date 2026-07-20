(function ($) {
	"use strict";
	var root = document.querySelector(".kidia-page-builder");
	if (!root) { return; }
	var list = document.getElementById("kidia-page-elements");
	var preview = document.getElementById("kidia-page-live-preview");
	var form = root.querySelector("form");
	var phoneScreen = root.querySelector(".kidia-page-phone__screen");
	var dragged = null;
	var frame = 0;
	var activePreviewElement = "";
	var config = window.kidiaPageBuilder || {};
	var products = Array.isArray(config.products) ? config.products : [];
	var previewCollapseProgress = 0;

	function array(value) { return Array.prototype.slice.call(value || []); }
	function escapeHtml(value) { return String(value || "").replace(/[&<>"']/g, function (c) { return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"}[c]; }); }
	function field(scope, suffix) { var items = scope ? scope.querySelectorAll('[name$="[' + suffix + ']"]') : []; return items.length ? items[items.length - 1] : null; }
	function value(scope, suffix, fallback) { var item = field(scope, suffix); return item ? item.value : fallback; }
	function checked(scope, suffix, fallback) { var item = field(scope, suffix); return item ? item.checked : fallback; }
	function color(scope, suffix, fallback) { var result = value(scope, suffix, fallback); return /^#[0-9a-f]{6}$/i.test(result) ? result : fallback; }
	function number(scope, suffix, fallback) { var result = Number(value(scope, suffix, fallback)); return isFinite(result) ? result : fallback; }
	function icon(name) { return '<span class="kidia-app-icon kidia-app-icon--' + name + '" aria-hidden="true"></span>'; }
	function money(item) { return escapeHtml(item && item.price ? item.price : "450 ج.م"); }
	function sampleProducts() { return products.length ? products : [{name:"طقم أطفال كيديا",price:"450 ج.م",image_url:""},{name:"كوليكشن جديد",price:"390 ج.م",image_url:""},{name:"ملابس أطفال",price:"320 ج.م",image_url:""},{name:"عرض خاص",price:"275 ج.م",image_url:""}]; }
	function actionPosition(value) { var top=String(value).indexOf("top_")===0,start=String(value).slice(-6)==="_start";return "top:"+(top?"5px":"auto")+";bottom:"+(top?"auto":"5px")+";inset-inline-start:"+(start?"5px":"auto")+";inset-inline-end:"+(start?"auto":"5px")+";right:auto;left:auto;"; }
	function quickAdd(card) { var variant=value(card,"quick_add_icon_variant","bag"),style=value(card,"quick_add_icon_style","outline"),name=variant==="cart"?"cart":variant==="basket"?"basket":"bag",size=Math.max(10,Math.min(36,number(card,"quick_add_icon_size",22))),shell=Math.max(20,Math.min(64,number(card,"quick_add_background_size",40))),background=checked(card,"quick_add_show_background",true)?color(card,"quick_add_background_color","#FFFFFF"):"transparent";return '<span class="kidia-app-quick-add is-'+escapeHtml(style)+'" style="'+actionPosition(value(card,"quick_add_position","bottom_end"))+'width:'+shell+'px;height:'+shell+'px;border-radius:'+number(card,"quick_add_radius",24)+'px;background:'+background+';color:'+color(card,"quick_add_icon_color","#1F2933")+';--quick-add-icon-size:'+size+'px">'+icon(name)+(variant==="bag"?'<b>+</b>':'')+'</span>'; }
	function productWishlist(card) { var variant=value(card,"product_wishlist_icon_variant","heart"),size=Math.max(10,Math.min(36,number(card,"product_wishlist_icon_size",20))),shell=Math.max(20,Math.min(64,number(card,"product_wishlist_background_size",40))),background=checked(card,"product_wishlist_show_background",true)?color(card,"product_wishlist_background_color","#FFFFFF"):"transparent";return '<span class="kidia-app-product-wishlist is-'+escapeHtml(value(card,"product_wishlist_icon_style","outline"))+'" style="'+actionPosition(value(card,"product_wishlist_position","top_end"))+'width:'+shell+'px;height:'+shell+'px;border-radius:'+number(card,"product_wishlist_radius",24)+'px;background:'+background+';color:'+color(card,"product_wishlist_icon_color","#1F2933")+';--wishlist-icon-size:'+size+'px">'+icon(variant==="bookmark"?"bookmark":"heart")+'</span>'; }
	function markDirty() { form.dispatchEvent(new window.CustomEvent("kidia:dirty", { bubbles: true })); }

	function updateIndexes() {
		array(list.querySelectorAll(".kidia-page-card")).forEach(function (card, index) {
			array(card.querySelectorAll("[name]")).forEach(function (input) {
				if (/^layout\[elements\]\[[^\]]+\]/.test(input.name)) { input.name = input.name.replace(/layout\[elements\]\[[^\]]+\]/, "layout[elements][" + index + "]"); }
			});
		});
	}

	function productCards(card, forcedLimit) {
		var columns = Math.max(1, Math.min(4, Math.round(number(card, "columns", 2))));
		var limit = Math.max(columns, Math.min(forcedLimit || number(card, "limit", 4), 6));
		var items = sampleProducts().slice(0, limit);
		var style = value(card, "card_style", "outlined");
		var gap = number(card, "gap", 12);
		return '<div class="kidia-app-products" style="--columns:' + columns + ';gap:' + gap + 'px">' + items.map(function (item) {
			var image = item.image_url ? '<img src="' + escapeHtml(item.image_url) + '" alt="">' : '<span class="kidia-app-product__fallback">K</span>';
			return '<article class="kidia-app-product is-' + style + '" style="border-radius:' + number(card, "card_radius", 16) + 'px"><div class="kidia-app-product__image" style="aspect-ratio:' + number(card, "image_ratio", 1) + '">' + image + (checked(card, "show_wishlist", false) ? productWishlist(card) : "") + (checked(card, "quick_add_enabled", true) ? quickAdd(card) : "") + (checked(card, "show_badge", true) ? '<b class="kidia-app-badge">SALE</b>' : "") + '</div><div class="kidia-app-product__copy"><strong>' + escapeHtml(item.name || "Kidia product") + '</strong>' + (checked(card, "show_rating", true) ? '<small class="kidia-app-rating">★ 4.8</small>' : "") + (checked(card, "show_price", true) ? '<b>' + money(item) + '</b>' : "") + (checked(card, "show_regular_price", true) ? '<del>520 ج.م</del>' : "") + '</div></article>';
		}).join("") + '</div>';
	}

	function renderHeader(card) {
		var titles = { catalog: "المنتجات", product: "", wishlist: "المفضلة", account: "حسابي" };
		if (window.KidiaChromePreview) { return window.KidiaChromePreview.renderHeader(card, titles[root.dataset.page] || "المنتجات", { collapseProgress: previewCollapseProgress, page: root.dataset.page }); }
		if (!card || !checked(card, "enabled", true)) { return ""; }
		var showBar = value(card, "search_style", "icon") === "bar" && checked(card, "show_search", true);
		var title = escapeHtml(value(card, "title", root.dataset.page === "account" ? "حسابي" : root.dataset.page === "product" ? "" : "المنتجات"));
		var actions = "";
		if (checked(card, "show_search", true) && !showBar) { actions += icon("search"); }
		if (checked(card, "show_wishlist", false)) { actions += icon("heart"); }
		if (checked(card, "show_cart", true)) { actions += icon("bag"); }
		if (checked(card, "show_account", false)) { actions += icon("person"); }
		return '<header class="kidia-app-header" style="height:' + number(card, "height", 64) + 'px;background:' + color(card, "background_color", "#FFFFFF") + ';color:' + color(card, "title_color", "#1F2933") + '"><span class="kidia-app-header__leading">' + (checked(card, "show_back", true) ? icon("back") : "") + '</span><div class="kidia-app-header__title">' + (showBar ? '<div class="kidia-app-search" style="height:' + number(card, "search_height", 40) + 'px;border-radius:' + number(card, "search_radius", 14) + 'px;background:' + color(card, "search_background", "#F1F3F4") + ';color:' + color(card, "search_text_color", "#5F6368") + '">' + icon("search") + '<span>' + escapeHtml(value(card, "search_placeholder", "Search products")) + '</span>' + (checked(card, "show_voice_search", false) ? icon("mic") : "") + '</div>' : '<strong>' + title + '</strong>') + '</div><div class="kidia-app-header__actions">' + actions + '</div></header>';
	}

	function pagination(card) {
		var mode = value(card, "pagination_mode", "load_more");
		if (mode === "none" || mode === "automatic") { return ""; }
		return '<div class="kidia-app-pagination" style="margin-top:' + number(card, "pagination_spacing", 16) + 'px">' + (mode === "numbers" ? '<button>1</button><button>2</button><button>3</button>' : '<button style="height:' + number(card, "pagination_size", 44) + 'px;background:' + color(card, "pagination_color", "#1F6F61") + ';color:' + color(card, "pagination_text_color", "#FFFFFF") + ';border-radius:' + number(card, "pagination_radius", 14) + 'px">' + escapeHtml(value(card, "pagination_label", "Load more")) + '</button>') + '</div>';
	}

	function previewElement(card) {
		var id = card.dataset.element || "element";
		var first = sampleProducts()[0] || {};
		if (id === "product_grid" || id === "wishlist_grid") {
			return '<section class="kidia-app-section">' + productCards(card, 4) + (id === "product_grid" ? pagination(card) : "") + '</section>';
		}
		if (id === "related_products") { return '<section class="kidia-app-section"><button class="kidia-app-related-button">✦ منتجات مشابهة</button></section>'; }
		if (id === "filter_bar") {
			var buttons = [];
			if (checked(card, "show_filter", true)) { buttons.push(icon("filter") + '<b>فلتر</b>'); }
			if (checked(card, "filter_size", true)) { buttons.push(icon("size") + '<b>المقاس</b>'); }
			if (checked(card, "show_sort", true)) { buttons.push(icon("sort") + '<b>ترتيب</b>'); }
			return '<div class="kidia-app-filter" style="width:' + number(card, "block_width", 100) + '%;height:' + number(card, "block_height", 68) + 'px;gap:' + number(card, "button_gap", 8) + 'px;background:' + color(card, "background_color", "#FFFFFF") + ';--icon-size:' + number(card, "icon_size", 22) + 'px;--icon-color:' + color(card, "icon_color", "#1F2933") + '">' + buttons.map(function (button) { return '<button style="border-color:' + color(card, "border_color", "#DDE3E8") + ';border-radius:' + number(card, "button_radius", 12) + 'px">' + button + '</button>'; }).join("") + (checked(card, "show_result_count", true) ? '<small>24 منتج</small>' : "") + '</div>';
		}
		if (id === "image_gallery") {
			var image = first.image_url ? '<img src="' + escapeHtml(first.image_url) + '" alt="">' : '<span class="kidia-app-gallery__fallback">KIDIA</span>';
			return '<section class="kidia-app-gallery" style="aspect-ratio:' + number(card, "aspect_ratio", 1) + '">' + image + (checked(card, "show_indicators", true) ? '<span class="kidia-app-gallery__count">1 / 4</span>' : "") + (checked(card, "enable_zoom", true) ? icon("zoom") : "") + '</section>';
		}
		if (id === "product_summary") {
			return '<section class="kidia-app-summary">' + (checked(card, "show_badge", true) ? '<span class="kidia-app-sale">خصم</span>' : "") + (checked(card, "show_name", true) ? '<h2>' + escapeHtml(first.name || "طقم أطفال كيديا") + '</h2>' : "") + (checked(card, "show_sku", true) ? '<small>SKU: KIDIA-001</small>' : "") + (checked(card, "show_rating", true) ? '<div class="kidia-app-stars">★★★★★ <u>11</u></div>' : "") + (checked(card, "show_price", true) ? '<div class="kidia-app-price"><b>' + money(first) + '</b>' + (checked(card, "show_regular_price", true) ? '<del>520 ج.م</del>' : "") + '</div>' : "") + (checked(card, "show_stock", true) ? '<small class="kidia-app-stock">متوفر</small>' : "") + '</section>';
		}
		if (id === "variations") {
			return '<section class="kidia-app-variations"><h3>اللون <span>وردي</span></h3><div><button class="is-selected">وردي</button><button>أصفر</button></div><h3>المقاس</h3><div><button>2Y</button><button class="is-selected">3Y</button><button>4Y</button></div></section>';
		}
		if (id === "purchase_bar") {
			return checked(card, "show_quantity", true) ? '<section class="kidia-app-purchase-inline"><strong>الكمية</strong><div class="kidia-app-quantity"><button>−</button><b>1</b><button>＋</button></div></section>' : '';
		}
		if (id === "description") {
			return '<section class="kidia-app-details"><h3>الوصف والتفاصيل</h3>' + (checked(card, "show_description", true) ? '<p>خامات مريحة وجودة مناسبة للأطفال.</p>' : "") + (checked(card, "show_attributes", true) ? '<div><span>الخامة</span><b>قطن</b></div><div><span>اللون</span><b>وردي</b></div>' : "") + (checked(card, "show_shipping", true) ? '<div><span>الشحن</span><b>2–5 أيام</b></div>' : "") + '</section>';
		}
		if (id === "reviews") { return '<section class="kidia-app-reviews"><h3>تقييمات العملاء</h3><b>4.8</b><span>★★★★★</span><small>بناءً على 11 تقييم</small></section>'; }
		if (id === "empty_state") { return '<section class="kidia-app-empty">' + icon("heart") + '<h3>' + escapeHtml(value(card, "title", "المفضلة فارغة")) + '</h3><p>' + escapeHtml(value(card, "description", "احفظي المنتجات التي تحبينها هنا")) + '</p>' + (checked(card, "show_button", true) ? '<button>' + escapeHtml(value(card, "button_label", "تسوقي الآن")) + '</button>' : "") + '</section>'; }
		if (id === "account_summary") { return '<section class="kidia-app-account-summary is-' + value(card, "card_style", "elevated") + '"><span class="kidia-app-avatar" style="width:' + number(card, "avatar_size", 66) + 'px;height:' + number(card, "avatar_size", 66) + 'px">B</span><div><strong>بسمة زيدان</strong>' + (checked(card, "show_email", true) ? '<small>customer@example.com</small>' : "") + '</div></section>'; }
		if (id === "account_menu") {
			var menu = [["orders","طلباتي"],["addresses","العناوين المحفوظة"],["profile","بيانات حسابي"],["support","خدمة العملاء"]].filter(function (item) { return checked(card, "show_" + item[0], true); });
			return '<section class="kidia-app-account-menu is-' + value(card, "style", "list") + '" style="--menu-color:' + color(card, "icon_color", "#1F6F61") + '">' + menu.map(function (item) { return '<div>' + icon(item[0]) + '<b>' + item[1] + '</b>' + icon("chevron") + '</div>'; }).join("") + '</section>';
		}
		if (id === "logout_button") { return '<button class="kidia-app-logout is-' + value(card, "style", "outline") + '" style="--logout-color:' + color(card, "color", "#B42318") + '">' + icon("logout") + escapeHtml(value(card, "label", "تسجيل الخروج")) + '</button>'; }
		return "";
	}

	function renderFooter(card) {
		if (window.KidiaChromePreview) { return window.KidiaChromePreview.renderFooter(card, { page: root.dataset.page }); }
		if (!card || !checked(card, "enabled", true)) { return ""; }
		if (value(card, "style", "navigation") === "product_action") {
			return '<footer class="kidia-app-footer kidia-app-footer--product" style="height:' + number(card, "height", 84) + 'px;background:' + color(card, "background_color", "#FFFFFF") + '">' + (checked(card, "show_share", true) ? '<span>' + icon("share") + '<b>' + escapeHtml(value(card, "share_label", "مشاركة")) + '</b></span>' : "") + (checked(card, "show_like", true) ? '<span>' + icon("heart") + '<b>' + escapeHtml(value(card, "like_label", "إعجاب")) + '</b></span>' : "") + (checked(card, "show_add_to_cart", true) ? '<button style="background:' + color(card, "button_color", "#1F2933") + ';color:' + color(card, "button_text_color", "#FFFFFF") + ';border-radius:' + number(card, "button_radius", 28) + 'px">' + escapeHtml(value(card, "add_to_cart_label", "أضف للحقيبة")) + '</button>' : "") + '</footer>';
		}
		var nav = [];
		if (checked(card, "show_home", true)) { nav.push(["home","الرئيسية"]); }
		if (checked(card, "show_categories", true)) { nav.push(["categories","الأقسام"]); }
		if (checked(card, "show_wishlist", true)) { nav.push(["heart","المفضلة"]); }
		if (checked(card, "show_account", true)) { nav.push(["person","حسابي"]); }
		return '<footer class="kidia-app-footer" style="height:' + number(card, "height", 72) + 'px;background:' + color(card, "background_color", "#FFFFFF") + ';color:' + color(card, "inactive_color", "#6B7280") + '">' + nav.map(function (item, index) { return '<span' + (index === 0 ? ' class="is-active" style="color:' + color(card, "active_color", "#1F6F61") + '"' : "") + '>' + icon(item[0]) + (checked(card, "show_labels", true) ? '<b>' + item[1] + '</b>' : "") + '</span>'; }).join("") + '</footer>';
	}

	function renderPreview() {
		frame = 0;
		var header = root.querySelector('[data-element="header"]');
		var footer = root.querySelector('[data-element="footer"]');
		var html = renderHeader(header) + '<main class="kidia-app-page kidia-app-page--' + escapeHtml(root.dataset.page || "page") + '">';
		array(list.querySelectorAll(".kidia-page-card")).forEach(function (card) { if (checked(card, "enabled", true)) { var background=value(card,"background_color","").trim()||"transparent",mergeUp=number(card,"margin_top",0),mergeDown=number(card,"margin_bottom",0);html += '<div class="kidia-page-element-frame" style="margin:0;transform:translateY('+(mergeDown-mergeUp)+'px);padding:'+number(card,"padding_vertical",0)+'px '+number(card,"padding_horizontal",0)+'px;background:'+escapeHtml(background)+'">'+previewElement(card)+'</div>'; } });
		html += '</main>' + renderFooter(footer);
		preview.innerHTML = html;
		var headerNode = preview.querySelector(".kidia-app-header");
		var footerNode = preview.querySelector(".kidia-app-footer");
		if (headerNode) { headerNode.classList.add("kidia-page-preview-header"); }
		if (footerNode) { footerNode.classList.add("kidia-page-preview-footer"); }
		array(preview.querySelectorAll(".kidia-app-product")).forEach(function (node) { node.classList.add("kidia-page-preview-product"); });
		array(list.querySelectorAll(".kidia-page-card")).forEach(function (card, index) {
			var rendered = preview.querySelectorAll(".kidia-app-page > *")[index];
			if (rendered) { rendered.classList.add("kidia-page-preview-element"); rendered.dataset.previewElement = card.dataset.element || ""; }
		});
		if(activePreviewElement){var active=activePreviewElement==="header"?preview.querySelector(".kidia-page-preview-header"):activePreviewElement==="footer"?preview.querySelector(".kidia-page-preview-footer"):preview.querySelector('[data-preview-element="'+activePreviewElement+'"]');if(active){active.classList.add("is-editor-focused");}}
	}
	function focusPreview(card) {
		if (!card || !preview) { return; }
		var part = card.dataset.element || "";
		activePreviewElement=part;
		var target = part === "header" ? preview.querySelector(".kidia-page-preview-header") : part === "footer" ? preview.querySelector(".kidia-page-preview-footer") : preview.querySelector('[data-preview-element="' + part + '"]');
		array(preview.querySelectorAll(".is-editor-focused")).forEach(function (node) { node.classList.remove("is-editor-focused"); });
		if (target) { target.classList.add("is-editor-focused"); target.scrollIntoView({behavior:"smooth",block:"center"}); }
	}
	function schedulePreview() {
		var requestFrame = window.requestAnimationFrame || function (callback) { callback(); return 0; };
		var cancelFrame = window.cancelAnimationFrame || function () {};
		if (frame) { cancelFrame(frame); }
		frame = requestFrame(renderPreview);
	}

	root.addEventListener("click", function (event) {
		var button = event.target.closest(".kidia-page-expand");
		var media = event.target.closest(".kidia-page-media-choose, .kidia-page-media-preview");
		if (button) { var card = button.closest(".kidia-page-card"); var body = card.querySelector(".kidia-page-card__body"); card.classList.toggle("is-open"); body.hidden = !card.classList.contains("is-open"); return; }
		if (media && !media.closest(".kidia-fixed-chrome-card") && window.wp && wp.media) { var mediaField = media.closest(".kidia-page-field--image"); var mediaFrame = wp.media({title:"Choose image",button:{text:"Use image"},multiple:false}); mediaFrame.on("select", function () { var attachment = mediaFrame.state().get("selection").first().toJSON(); var input = mediaField.querySelector(".kidia-page-media-url"); var image = mediaField.querySelector(".kidia-page-media-preview"); input.value = attachment.url || ""; image.src = attachment.url || ""; image.hidden = !attachment.url; markDirty(); schedulePreview(); }); mediaFrame.open(); }
	});
	root.addEventListener("change", schedulePreview);
	root.addEventListener("input", schedulePreview);
	// Clicking an empty builder area must release a previously focused control.
	// Otherwise ArrowUp/ArrowDown keep changing that control and the page appears
	// stuck instead of scrolling in the requested direction.
	root.addEventListener("pointerdown", function (event) {
		var target = event.target;
		var active = window.document.activeElement;
		var interactive = target && target.closest && target.closest("input, select, textarea, button, a, label, [contenteditable='true'], .kidia-page-drag, .kidia-builder-drag");
		if (!interactive && active && root.contains(active) && /^(INPUT|SELECT|TEXTAREA|BUTTON)$/.test(active.tagName) && typeof active.blur === "function") {
			active.blur();
		}
	});
	root.addEventListener("click", function (event) {
		var card=event.target.closest(".kidia-page-card");
		if(card && event.target.closest(".kidia-page-card__header")){focusPreview(card);}
	});
	list.addEventListener("pointerdown", function (event) { var handle = event.target.closest(".kidia-page-drag"); var card = handle ? handle.closest(".kidia-page-card") : null; if (card) { card.draggable = true; } });
	list.addEventListener("dragstart", function (event) { var card = event.target.closest(".kidia-page-card"); if (!card || !card.draggable) { event.preventDefault(); return; } dragged = card; card.classList.add("is-dragging"); });
	list.addEventListener("dragover", function (event) { if (!dragged) { return; } event.preventDefault(); var target = event.target.closest(".kidia-page-card"); if (!target || target === dragged) { return; } var rect = target.getBoundingClientRect(); target.insertAdjacentElement(event.clientY > rect.top + rect.height / 2 ? "afterend" : "beforebegin", dragged); });
	list.addEventListener("dragend", function () { if (dragged) { dragged.classList.remove("is-dragging"); dragged.draggable = false; } dragged = null; updateIndexes(); markDirty(); schedulePreview(); });
	form.addEventListener("submit", function () { updateIndexes(); var button = root.querySelector('button[type="submit"],input[type="submit"]'); if (button) { button.disabled = true; button.setAttribute("aria-busy", "true"); } });
	window.addEventListener("pageshow", function () { var button = root.querySelector('button[type="submit"],input[type="submit"]'); if (button) { button.disabled = false; button.removeAttribute("aria-busy"); } });
	if (phoneScreen) { phoneScreen.addEventListener("scroll", function () { previewCollapseProgress=Math.max(0,Math.min(1,phoneScreen.scrollTop/64));if(window.KidiaChromePreview){window.KidiaChromePreview.updateHeaderProgress(preview.querySelector(".kidia-app-header"),previewCollapseProgress);} }, {passive:true}); }
	if ($ && $.fn && $.fn.sortable) { $(list).sortable({handle:".kidia-page-drag",items:"> .kidia-page-card",update:function(){updateIndexes();markDirty();schedulePreview();}}); }
	updateIndexes(); renderPreview();
}(window.jQuery));
