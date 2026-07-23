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
	function quickAdd(card) { var variant=value(card,"quick_add_icon_variant","bag"),style=value(card,"quick_add_icon_style","outline"),name=variant==="cart"?"cart":variant==="basket"?"basket":"bag",size=Math.max(10,Math.min(36,number(card,"quick_add_icon_size",22))),shell=Math.max(10,Math.min(64,number(card,"quick_add_background_size",40))),background=checked(card,"quick_add_show_background",true)?color(card,"quick_add_background_color","#FFFFFF"):"transparent";return '<span class="kidia-app-quick-add is-'+escapeHtml(style)+'" style="'+actionPosition(value(card,"quick_add_position","bottom_end"))+'width:'+shell+'px;height:'+shell+'px;border-radius:'+number(card,"quick_add_radius",24)+'px;background:'+background+';color:'+color(card,"quick_add_icon_color","#1F2933")+';--quick-add-icon-size:'+size+'px">'+icon(name)+(variant==="bag"?'<b>+</b>':'')+'</span>'; }
	function productWishlist(card) { var variant=value(card,"product_wishlist_icon_variant","heart"),size=Math.max(10,Math.min(36,number(card,"product_wishlist_icon_size",20))),shell=Math.max(20,Math.min(64,number(card,"product_wishlist_background_size",40))),background=checked(card,"product_wishlist_show_background",true)?color(card,"product_wishlist_background_color","#FFFFFF"):"transparent";return '<span class="kidia-app-product-wishlist is-'+escapeHtml(value(card,"product_wishlist_icon_style","outline"))+'" style="'+actionPosition(value(card,"product_wishlist_position","top_end"))+'width:'+shell+'px;height:'+shell+'px;border-radius:'+number(card,"product_wishlist_radius",24)+'px;background:'+background+';color:'+color(card,"product_wishlist_icon_color","#1F2933")+';--wishlist-icon-size:'+size+'px">'+icon(variant==="bookmark"?"bookmark":"heart")+'</span>'; }
	function markDirty() { form.dispatchEvent(new window.CustomEvent("kidia:dirty", { bubbles: true })); }
	function productTabs(card) {
		var raw = value(card, "tabs_json", "");
		try {
			var parsed = JSON.parse(raw);
			if (Array.isArray(parsed)) {
				return parsed.filter(function (tab) { return tab && tab.enabled !== false && tab.label; }).slice(0, 10);
			}
		} catch (error) {}
		return [{label:"Overview",target:"overview",enabled:true},{label:"Reviews",target:"reviews",enabled:true},{label:"Recommend",target:"recommend",enabled:true}];
	}
	function syncProductTabs(editor) {
		if (!editor) { return; }
		var rows = array(editor.querySelectorAll(".kidia-product-tab-row")).map(function (row) {
			return {
				label: (row.querySelector(".kidia-product-tab-label").value || "").trim(),
				target: row.querySelector(".kidia-product-tab-target").value || "overview",
				enabled: row.querySelector(".kidia-product-tab-enabled input").checked
			};
		}).filter(function (tab) { return tab.label; }).slice(0, 10);
		var input = editor.querySelector(".kidia-product-tabs-json");
		input.value = JSON.stringify(rows);
		input.dispatchEvent(new window.Event("input", { bubbles: true }));
	}
	function productTabRow(editor) {
		var row = document.createElement("div");
		row.className = "kidia-product-tab-row";
		row.innerHTML = '<input type="text" class="kidia-product-tab-label" value="New tab" placeholder="Tab label"><select class="kidia-product-tab-target"><option value="overview">Overview / product information</option><option value="variations">Variations</option><option value="description">Description</option><option value="reviews">Reviews</option><option value="recommend">Related products</option></select><label class="kidia-product-tab-enabled"><input type="checkbox" checked>Show</label><button type="button" class="button kidia-product-tab-remove" aria-label="Remove tab"><span class="dashicons dashicons-trash"></span></button>';
		editor.querySelector(".kidia-product-tabs-rows").appendChild(row);
		syncProductTabs(editor);
	}
	function wishlistPreviewState() {
		var selected = form.querySelector('[name="layout[settings][wishlist_preview_state]"]:checked');
		return selected && ["sign_in", "empty", "products"].indexOf(selected.value) !== -1 ? selected.value : "products";
	}
	function wishlistAccessMode() {
		var selected = form.querySelector('[name="layout[settings][wishlist_access_mode]"]:checked');
		return selected && selected.value === "guest" ? "guest" : "sign_in_required";
	}
	function applyWishlistAccessMode() {
		if (root.dataset.page !== "wishlist") { return; }
		var guest = wishlistAccessMode() === "guest";
		var signInOption = form.querySelector('[data-wishlist-preview-state="sign_in"]');
		var signInRadio = signInOption && signInOption.querySelector('input[type="radio"]');
		if (signInOption) {
			signInOption.classList.toggle("is-disabled", guest);
			signInOption.setAttribute("aria-disabled", guest ? "true" : "false");
		}
		if (signInRadio) { signInRadio.disabled = guest; }
		if (guest && wishlistPreviewState() === "sign_in") {
			var empty = form.querySelector('[name="layout[settings][wishlist_preview_state]"][value="empty"]');
			if (empty) { empty.checked = true; }
		}
	}
	function applyWishlistPreviewState(options) {
		if (root.dataset.page !== "wishlist") { return; }
		var state = wishlistPreviewState();
		array(list.querySelectorAll("[data-wishlist-state]")).forEach(function (card) {
			var active = card.dataset.wishlistState === state;
			card.hidden = !active;
			card.classList.toggle("is-wishlist-state-hidden", !active);
			if (active && options && options.open) {
				var body = card.querySelector(":scope > .kidia-page-card__body");
				card.classList.add("is-open");
				if (body) { body.hidden = false; }
				var expand = card.querySelector(".kidia-page-expand");
				if (expand) { expand.setAttribute("aria-expanded", "true"); }
				focusPreview(card);
			}
		});
		var addSelect = document.getElementById("kidia-wishlist-add-element-type");
		if (addSelect) {
			var firstVisible = null;
			array(addSelect.options).forEach(function (option) {
				var visible = option.dataset.wishlistState === state;
				option.hidden = !visible;
				option.disabled = !visible;
				if (visible && !firstVisible) { firstVisible = option; }
			});
			if (!addSelect.selectedOptions.length || addSelect.selectedOptions[0].disabled) {
				addSelect.value = firstVisible ? firstVisible.value : "";
			}
		}
	}

	function updateIndexes() {
		array(list.querySelectorAll(".kidia-page-card")).forEach(function (card, index) {
			array(card.querySelectorAll("[name]")).forEach(function (input) {
				if (/^layout\[elements\]\[[^\]]+\]/.test(input.name)) { input.name = input.name.replace(/layout\[elements\]\[[^\]]+\]/, "layout[elements][" + index + "]"); }
			});
		});
	}

	function duplicateWishlistElement(card) {
		var clone = card.cloneNode(true);
		var controls = array(card.querySelectorAll("input,select,textarea"));
		array(clone.querySelectorAll("input,select,textarea")).forEach(function (target, index) {
			var source = controls[index];
			if (!source) { return; }
			if (target.type === "checkbox" || target.type === "radio") { target.checked = source.checked; }
			else { target.value = source.value; }
		});
		var type = card.dataset.element || "element";
		var instance = type + "__" + Date.now().toString(36) + "_" + Math.random().toString(36).slice(2, 7);
		clone.dataset.instanceId = instance;
		var idInput = clone.querySelector(".kidia-page-element-id");
		if (idInput) { idInput.value = instance; }
		var remove = clone.querySelector(".kidia-page-remove");
		if (remove) { remove.hidden = false; }
		clone.classList.add("is-open");
		var body = clone.querySelector(":scope > .kidia-page-card__body");
		if (body) { body.hidden = false; }
		card.insertAdjacentElement("afterend", clone);
		updateIndexes();
		markDirty();
		schedulePreview();
		focusPreview(clone);
	}
	function addWishlistElement() {
		var select = document.getElementById("kidia-wishlist-add-element-type");
		var source = select && list.querySelector('[data-element="' + select.value + '"]');
		if (!source || source.dataset.wishlistState !== wishlistPreviewState()) { return; }
		duplicateWishlistElement(source);
	}

	function productCards(card, forcedLimit) {
		var columns = Math.max(1, Math.min(4, Math.round(number(card, "columns", 2))));
		var limit = Math.max(columns, Math.min(forcedLimit || number(card, "products_per_page", number(card, "limit", 4)), 6));
		var items = sampleProducts().slice(0, limit);
		var style = value(card, "card_style", "outlined");
		var gap = number(card, "gap", 12);
		return '<div class="kidia-app-products" style="--columns:' + columns + ';gap:' + gap + 'px">' + items.map(function (item) {
			var image = item.image_url ? '<img src="' + escapeHtml(item.image_url) + '" alt="">' : '<span class="kidia-app-product__fallback">K</span>';
			var showQuickAdd = field(card, "show_quick_add") ? checked(card, "show_quick_add", true) : checked(card, "quick_add_enabled", true);
			var copy = (checked(card, "show_name", true) ? '<strong>' + escapeHtml(item.name || "Kidia product") + '</strong>' : "") + (checked(card, "show_rating", false) ? '<small class="kidia-app-rating">★ 4.8</small>' : "") + (checked(card, "show_price", true) ? '<b>' + money(item) + '</b>' : "") + (checked(card, "show_regular_price", false) ? '<del>520 ج.م</del>' : "");
			return '<article class="kidia-app-product is-' + style + '" style="border-radius:' + number(card, "card_radius", 0) + 'px"><div class="kidia-app-product__image" style="aspect-ratio:' + number(card, "image_ratio", 1) + '">' + image + (checked(card, "show_wishlist", false) ? productWishlist(card) : "") + (showQuickAdd ? quickAdd(card) : "") + (checked(card, "show_badge", false) ? '<b class="kidia-app-badge">SALE</b>' : "") + '</div>' + (copy ? '<div class="kidia-app-product__copy">' + copy + '</div>' : "") + '</article>';
		}).join("") + '</div>';
	}

	function wishlistMessage(card, signIn) {
		var imageUrl = value(card, "illustration_url", "");
		var illustration = imageUrl
			? '<img class="kidia-app-wishlist-illustration" src="' + escapeHtml(imageUrl) + '" alt="">'
			: '<span class="kidia-app-wishlist-bag" aria-hidden="true"><i></i></span>';
		var buttonStyle = value(card, "button_style", "outline");
		return '<section class="kidia-app-empty kidia-app-wishlist-message" style="padding-top:' + number(card, "top_spacing", 56) + 'px;padding-bottom:' + number(card, "bottom_spacing", 96) + 'px;--wishlist-illustration-size:' + number(card, "illustration_size", 104) + 'px;--wishlist-content-gap:' + number(card, "content_gap", 16) + 'px">' +
			illustration +
			'<h3 style="font-size:' + number(card, "title_size", 18) + 'px;font-weight:' + escapeHtml(value(card, "title_weight", "700")) + '">' + escapeHtml(value(card, "title", signIn ? "Sign in to view your wishlist" : "Your wishlist is empty")) + '</h3>' +
			(checked(card, "show_description", !signIn) ? '<p style="font-size:' + number(card, "description_size", 14) + 'px">' + escapeHtml(value(card, "description", "")) + '</p>' : "") +
			(checked(card, "show_button", true) ? '<button class="is-' + escapeHtml(buttonStyle) + '" style="width:' + number(card, "button_width", 220) + 'px;height:' + number(card, "button_height", 52) + 'px;border-radius:' + number(card, "button_radius", 26) + 'px;border:' + number(card, "button_border_width", 1.5) + 'px solid ' + color(card, "button_border_color", "#1D1D1D") + ';background:' + (buttonStyle === "filled" ? color(card, "button_color", "#1D1D1D") : "transparent") + ';color:' + color(card, "button_text_color", "#1D1D1D") + '">' + escapeHtml(value(card, "button_label", signIn ? "Sign In" : "Go Shopping")) + '</button>' : "") +
			'</section>';
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
		if (id === "product_tabs") {
			var tabs = productTabs(card);
			return '<nav class="kidia-app-section kidia-app-product-tabs" style="display:flex;overflow-x:auto;height:' + number(card, "height", 64) + 'px;align-items:stretch;background:#fff;color:' + color(card, "inactive_color", "#6B6B6B") + '">' + tabs.map(function (tab, index) { return '<b style="flex:1 0 110px;display:grid;place-items:center;color:' + (index === 0 ? color(card, "active_color", "#1D1D1D") : "inherit") + ';border-bottom:' + (index === 0 ? "3px solid currentColor" : "0") + ';padding:8px">' + escapeHtml(tab.label) + '</b>'; }).join("") + '</nav>';
		}
		if (id === "related_products" || /_recommendations$/.test(id)) { return '<section class="kidia-app-section kidia-app-wishlist-recommendations" style="padding-inline:' + number(card, "section_padding", 16) + 'px"><h2 style="font-size:' + number(card, "title_size", 20) + 'px;font-weight:' + escapeHtml(value(card, "title_weight", "700")) + ';margin-bottom:' + number(card, "title_bottom_spacing", 18) + 'px">' + escapeHtml(value(card, "title", "You may also like")) + '</h2>' + productCards(card, number(card, "limit", 4)) + '</section>'; }
		if (id === "filter_bar") {
			var buttons = [];
			if (checked(card, "show_filter", true)) { buttons.push(icon("filter") + '<b>فلتر</b>'); }
			if (checked(card, "filter_price", true)) { buttons.push(icon("price") + '<b>السعر</b>'); }
			if (checked(card, "filter_sale", true)) { buttons.push(icon("sale") + '<b>العروض</b>'); }
			if (checked(card, "filter_brand", true)) { buttons.push(icon("brand") + '<b>العلامة</b>'); }
			if (checked(card, "filter_size", true)) { buttons.push(icon("size") + '<b>المقاس</b>'); }
			if (checked(card, "show_sort", true)) { buttons.push(icon("sort") + '<b>ترتيب</b>'); }
			return '<div class="kidia-app-filter' + (checked(card, "sticky", false) ? " is-sticky" : "") + '" style="width:' + number(card, "block_width", 100) + '%;height:' + number(card, "block_height", 56) + 'px;gap:' + number(card, "button_gap", 8) + 'px;background:' + color(card, "background_color", "#FFFFFF") + ';--icon-size:' + number(card, "icon_size", 22) + 'px;--icon-color:' + color(card, "icon_color", "#1F2933") + ';--icon-offset-y:' + number(card, "filter_icon_offset_y", -2) + 'px">' + buttons.map(function (button) { return '<button style="border-color:' + color(card, "border_color", "#DDE3E8") + ';border-radius:' + number(card, "button_radius", 12) + 'px">' + button + '</button>'; }).join("") + (checked(card, "show_result_count", false) ? '<small>24 منتج</small>' : "") + '</div>';
		}
		if (id === "image_gallery") {
			var image = first.image_url ? '<img src="' + escapeHtml(first.image_url) + '" alt="">' : '<span class="kidia-app-gallery__fallback">KIDIA</span>';
			return '<section class="kidia-app-gallery" style="aspect-ratio:' + number(card, "aspect_ratio", .75) + ';--gallery-fit:' + escapeHtml(value(card, "fit", "contain")) + ';background:' + color(card, "background_color", "#F4F2F3") + '">' + image + (checked(card, "show_counter", true) ? '<span class="kidia-app-gallery__count" style="background:' + color(card, "counter_background", "#8A8585") + ';color:' + color(card, "counter_text_color", "#FFFFFF") + '">1 / 4</span>' : "") + (checked(card, "show_thumbnails", false) ? '<span class="kidia-app-gallery__thumbnails">● ● ●</span>' : "") + (checked(card, "enable_zoom", false) ? icon("zoom") : "") + '</section>';
		}
		if (id === "product_summary") {
			return '<section class="kidia-app-summary">' + (checked(card, "show_badge", false) ? '<span class="kidia-app-sale">خصم</span>' : "") + '<div style="display:flex;justify-content:space-between;align-items:center">' + (checked(card, "show_price", true) ? '<div class="kidia-app-price"><b>' + money(first) + '</b>' + (checked(card, "show_regular_price", true) ? '<del>520 ج.م</del>' : "") + '</div>' : "") + (checked(card, "show_rating", true) ? '<div class="kidia-app-stars">★★★★★ ' + (checked(card, "show_review_count", true) ? '<u>252</u>' : '') + '</div>' : "") + '</div>' + (checked(card, "show_name", true) ? '<h2>' + escapeHtml(first.name || "Toddler Girl Dress") + '</h2>' : "") + (checked(card, "show_sku", false) ? '<small>SKU: KIDIA-001</small>' : "") + (checked(card, "show_stock", false) ? '<small class="kidia-app-stock">متوفر</small>' : "") + '</section>';
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
		if (id === "reviews") { return '<section class="kidia-app-reviews"><h3>' + escapeHtml(value(card, "title", "Reviews")) + ' (252) ›</h3><b>4.5</b><span>★★★★☆</span><small>Small 1% · True to size 99% · Large 0%</small></section>'; }
		if (id === "sign_in_state") { return wishlistMessage(card, true); }
		if (id === "empty_state") { return wishlistMessage(card, false); }
		if (id === "account_summary") { return '<section class="kidia-app-account-summary is-' + value(card, "card_style", "elevated") + '"><span class="kidia-app-avatar" style="width:' + number(card, "avatar_size", 66) + 'px;height:' + number(card, "avatar_size", 66) + 'px">B</span><div><strong>' + escapeHtml(value(card, "guest_title", "بسمة زيدان")) + '</strong>' + (checked(card, "show_email", true) ? '<small>customer@example.com</small>' : "") + (checked(card, "show_addresses", true) ? '<small>العناوين</small>' : "") + (checked(card, "show_profile", true) ? '<small>الملف الشخصي</small>' : "") + '</div></section>'; }
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
		var pageBackgroundInput = form.querySelector('[name="layout[settings][page_background_color]"]');
		var pageBackground = root.dataset.page === "product" && pageBackgroundInput && /^#[0-9a-f]{6}$/i.test(pageBackgroundInput.value) ? pageBackgroundInput.value : root.dataset.page === "product" ? "#FFFFFF" : "";
		var html = renderHeader(header) + '<main class="kidia-app-page kidia-app-page--' + escapeHtml(root.dataset.page || "page") + '"' + (pageBackground ? ' style="background:' + escapeHtml(pageBackground) + '"' : '') + '>';
		array(list.querySelectorAll(".kidia-page-card")).forEach(function (card) { if (!card.hidden && checked(card, "enabled", true)) { var background=value(card,"background_color","").trim()||"transparent",mergeUp=number(card,"margin_top",0),mergeDown=number(card,"margin_bottom",0),legacySpace=number(card,"padding_vertical",0);html += '<div class="kidia-page-element-frame" style="margin:0;transform:translateY('+(mergeDown-mergeUp)+'px);padding:'+number(card,"space_up",legacySpace)+'px '+number(card,"padding_horizontal",0)+'px '+number(card,"space_down",legacySpace)+'px;background:'+escapeHtml(background)+'">'+previewElement(card)+'</div>'; } });
		html += '</main>' + renderFooter(footer);
		preview.innerHTML = html;
		var headerNode = preview.querySelector(".kidia-app-header");
		var footerNode = preview.querySelector(".kidia-app-footer");
		if (headerNode) { headerNode.classList.add("kidia-page-preview-header"); }
		if (footerNode) { footerNode.classList.add("kidia-page-preview-footer"); }
		array(preview.querySelectorAll(".kidia-app-product")).forEach(function (node) { node.classList.add("kidia-page-preview-product"); });
		array(list.querySelectorAll(".kidia-page-card:not([hidden])")).forEach(function (card, index) {
			var rendered = preview.querySelectorAll(".kidia-app-page > *")[index];
			if (rendered) { rendered.classList.add("kidia-page-preview-element"); rendered.dataset.previewElement = card.dataset.instanceId || card.dataset.element || ""; }
		});
		if(activePreviewElement){var active=activePreviewElement==="header"?preview.querySelector(".kidia-page-preview-header"):activePreviewElement==="footer"?preview.querySelector(".kidia-page-preview-footer"):preview.querySelector('[data-preview-element="'+activePreviewElement+'"]');if(active){active.classList.add("is-editor-focused");}}
	}
	function focusPreview(card) {
		if (!card || !preview) { return; }
		var part = card.dataset.instanceId || card.dataset.element || "";
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
		var collapseAll = event.target.closest("#kidia-collapse-all");
		var expandAll = event.target.closest("#kidia-expand-all");
		if (collapseAll || expandAll) {
			var opening = Boolean(expandAll);
			array(root.querySelectorAll(".kidia-page-card:not(.kidia-fixed-chrome-card)")).forEach(function (card) {
				var body = card.querySelector(":scope > .kidia-page-card__body");
				var toggle = card.querySelector(":scope > .kidia-page-card__header .kidia-page-expand, :scope > .kidia-page-card__header .kidia-fixed-chrome-expand");
				if (body) { body.hidden = !opening; }
				card.classList.toggle("is-open", opening);
				if (toggle) { toggle.setAttribute("aria-expanded", opening ? "true" : "false"); }
			});
			return;
		}
		var duplicate = event.target.closest(".kidia-page-duplicate");
		if (duplicate) {
			duplicateWishlistElement(duplicate.closest(".kidia-page-card"));
			return;
		}
		if (event.target.closest("#kidia-wishlist-add-element")) {
			addWishlistElement();
			return;
		}
		var addTab = event.target.closest(".kidia-product-tab-add");
		if (addTab) {
			var editor = addTab.closest(".kidia-product-tabs-editor");
			if (editor.querySelectorAll(".kidia-product-tab-row").length < 10) {
				productTabRow(editor);
				markDirty();
			}
			return;
		}
		var removeTab = event.target.closest(".kidia-product-tab-remove");
		if (removeTab) {
			var tabEditor = removeTab.closest(".kidia-product-tabs-editor");
			if (tabEditor.querySelectorAll(".kidia-product-tab-row").length > 1) {
				removeTab.closest(".kidia-product-tab-row").remove();
				syncProductTabs(tabEditor);
				markDirty();
			}
			return;
		}
		var remove = event.target.closest(".kidia-page-remove");
		if (remove) {
			var removableCard = remove.closest(".kidia-page-card");
			if (removableCard && removableCard.dataset.instanceId !== removableCard.dataset.element) {
				removableCard.remove();
				updateIndexes();
				markDirty();
				schedulePreview();
			}
			return;
		}
		var button = event.target.closest(".kidia-page-expand");
		var media = event.target.closest(".kidia-page-media-choose, .kidia-page-media-preview");
		if (button && !button.closest(".kidia-fixed-chrome-card")) { var card = button.closest(".kidia-page-card"); var body = card.querySelector(".kidia-page-card__body"); card.classList.toggle("is-open"); body.hidden = !card.classList.contains("is-open"); return; }
		if (media && !media.closest(".kidia-fixed-chrome-card") && window.wp && wp.media) { var mediaField = media.closest(".kidia-page-field--image"); var mediaFrame = wp.media({title:"Choose image",button:{text:"Use image"},multiple:false}); mediaFrame.on("select", function () { var attachment = mediaFrame.state().get("selection").first().toJSON(); var input = mediaField.querySelector(".kidia-page-media-url"); var image = mediaField.querySelector(".kidia-page-media-preview"); input.value = attachment.url || ""; image.src = attachment.url || ""; image.hidden = !attachment.url; markDirty(); schedulePreview(); }); mediaFrame.open(); }
	});
	root.addEventListener("change", schedulePreview);
	root.addEventListener("input", schedulePreview);
	root.addEventListener("input", function (event) {
		var editor = event.target.closest && event.target.closest(".kidia-product-tabs-editor");
		if (editor && !event.target.classList.contains("kidia-product-tabs-json")) { syncProductTabs(editor); }
	});
	root.addEventListener("change", function (event) {
		var editor = event.target.closest && event.target.closest(".kidia-product-tabs-editor");
		if (editor && !event.target.classList.contains("kidia-product-tabs-json")) { syncProductTabs(editor); }
	});
	root.addEventListener("click", function (event) {
		var option = event.target.closest(".kidia-wishlist-access-option, .kidia-wishlist-preview-option");
		var radio = option && option.querySelector('input[type="radio"]');
		if (!radio || event.target === radio || radio.checked) { return; }
		event.preventDefault();
		radio.checked = true;
		radio.dispatchEvent(new window.Event("input", { bubbles: true }));
		radio.dispatchEvent(new window.Event("change", { bubbles: true }));
	});
	root.addEventListener("change", function (event) {
		if (event.target.matches('[name="layout[settings][wishlist_preview_state]"]')) {
			applyWishlistPreviewState();
			markDirty();
			document.dispatchEvent(new window.CustomEvent("kidia:page-layout-changed", {
				detail: { page: "wishlist", wishlistPreviewState: event.target.value },
			}));
			return;
		}
		if (!event.target.matches('[name="layout[settings][wishlist_access_mode]"]')) { return; }
		applyWishlistAccessMode();
		applyWishlistPreviewState();
		markDirty();
		document.dispatchEvent(new window.CustomEvent("kidia:page-layout-changed", {
			detail: { page: "wishlist", wishlistAccessMode: event.target.value },
		}));
	});
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
	updateIndexes(); applyWishlistAccessMode(); applyWishlistPreviewState(); renderPreview();
}(window.jQuery));
