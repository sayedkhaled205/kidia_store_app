(function () {
	"use strict";

	if (!window.jQuery) {
		return;
	}

	var $ = window.jQuery;
	var builder = $(".kidia-category-builder").first();
	var preview = $("#kidia-category-live-preview");
	var form = builder.find(".kidia-category-editor form").first();
	var general = builder.find(".kidia-category-general").first();
	var categoryElement = builder.find(".kidia-category-element").first();
	var phoneScreen = builder.find(".kidia-category-phone__screen").get(0);
	var expandedTerms = {};
	var previewScrolled = false;

	if (!builder.length || !preview.length || !form.length || !general.length) {
		return;
	}

	window.kidiaCategoryBuilderBooted = true;

	function markDirty() {
		form.get(0).dispatchEvent(new window.CustomEvent("kidia:dirty", { bubbles: true }));
	}

	function field(scope, suffix) {
		var fields = scope.find('[name$="[' + suffix + ']"]');
		return fields.length ? fields.last() : $();
	}

	function setting(suffix) {
		var input = field(general, suffix);
		return input.length ? input.val() : "";
	}

	function numberInRange(value, fallback, minimum, maximum) {
		var parsed = Number(value);
		if (!isFinite(parsed)) {
			parsed = fallback;
		}
		return Math.max(minimum, Math.min(maximum, parsed));
	}

	function imagePosition(value) {
		return {
			center: "center",
			top: "center top",
			bottom: "center bottom",
			left: "left center",
			right: "right center"
		}[value] || "center";
	}

	function textAlignment(value) {
		if (value === "center") {
			return "center";
		}
		return value === "end" ? "left" : "right";
	}

	function updateOrders(list) {
		$(list).children(".kidia-category-row").each(function (index) {
			$(this).children(".kidia-category-card").find(".kidia-category-order").val(index);
		});
	}

	function categoryKey(row) {
		return String(row.attr("data-term-id") || "");
	}

	function isRowExpanded(row) {
		var key = categoryKey(row);
		if (key && Object.prototype.hasOwnProperty.call(expandedTerms, key)) {
			return expandedTerms[key];
		}
		return row.children(".kidia-category-card").find(".kidia-category-expand").first().attr("aria-expanded") === "true";
	}

	function setRowExpanded(row, expanded) {
		var key = categoryKey(row);
		var button = row.children(".kidia-category-card").find(".kidia-category-expand").first();
		var children = row.children(".kidia-category-children");
		var nextState = Boolean(expanded);
		if (key) {
			expandedTerms[key] = nextState;
		}
		button.attr("aria-expanded", nextState ? "true" : "false");
		children.prop("hidden", !nextState);
	}

	function elementEnabled() {
		return categoryElement.find(".kidia-category-element-enabled").prop("checked");
	}

	function categoryLayout() {
		var layout = String(setting("category_layout") || "default");
		return ["default", "visual_grid", "circular_grid", "compact_grid", "sidebar"].indexOf(layout) >= 0 ? layout : "default";
	}

	function applyArtworkStyles(box, image, maximumSize) {
		var size = numberInRange(setting("image_size"), 68, 32, maximumSize);
		var shape = setting("image_shape") || "rounded";
		var radius = numberInRange(setting("image_radius"), 18, 0, 50);
		var effect = setting("image_effect") || "none";

		box.css({
			width: size + "px",
			height: size + "px",
			borderRadius: shape === "circle" ? "50%" : shape === "rounded" ? radius + "%" : "0",
			border: numberInRange(setting("border_width"), 0, 0, 8) + "px solid " + (setting("border_color") || "#DDE5E2"),
			backgroundColor: setting("background_color") || "#FFFFFF",
			boxShadow: effect === "shadow" ? "0 4px 10px rgba(0,0,0,.2)" : "none"
		});

		image.css({
			objectFit: setting("image_fit") || "contain",
			objectPosition: imagePosition(setting("image_position")),
			transform: "scale(" + numberInRange(setting("image_scale"), 100, 80, 150) / 100 + ")",
			filter: effect === "grayscale" ? "grayscale(1)" : "none"
		});
	}

	function applyNameStyles(name, isChild) {
		var requestedSize = numberInRange(setting("font_size"), 16, 10, 30);
		name.css({
			fontSize: (isChild ? Math.min(requestedSize, 14) : Math.min(requestedSize, 18)) + "px",
			color: setting("font_color") || "#1F2933",
			fontWeight: setting("font_weight") || "800",
			textAlign: textAlignment(setting("text_align")),
			lineHeight: numberInRange(setting("line_height"), 125, 100, 200) / 100,
			display: "-webkit-box",
			WebkitBoxOrient: "vertical",
			WebkitLineClamp: String(numberInRange(setting("text_max_lines"), 2, 1, 3)),
			overflow: "hidden"
		});
	}

	function updateEditorArtwork(card) {
		var artwork = card.find(".kidia-category-image").first();
		applyArtworkStyles(artwork, artwork.find("img"), 52);
	}

	function buildArtwork(card, maximumSize) {
		var source = card.find(".kidia-category-image img").attr("src") || "";
		var box = $('<div class="kidia-category-preview-image"></div>');
		var image;
		if (source) {
			image = $('<img alt="">').attr("src", source);
			box.append(image);
		} else {
			image = $("<span></span>");
			box.append('<span class="dashicons dashicons-category kidia-category-preview-placeholder"></span>');
		}
		applyArtworkStyles(box, image, maximumSize);
		return box;
	}

	function buildCategoryName(row, card, isChild) {
		var name = $('<div class="kidia-category-preview-name"></div>');
		var input = card.find(".kidia-category-name-input").first();
		name.text(String(input.val() || row.attr("data-default-name") || ""));
		applyNameStyles(name, isChild);
		return name;
	}

	function isHidden(card) {
		return !card.find('.kidia-category-visibility input[type="checkbox"]').is(":checked");
	}

	function buildChildCard(row) {
		var card = row.children(".kidia-category-card");
		var mobileCard = $('<div class="kidia-category-preview-child"></div>');
		if (isHidden(card)) {
			return null;
		}
		mobileCard.append(buildArtwork(card, 60));
		mobileCard.append(buildCategoryName(row, card, true).css("margin-top", numberInRange(setting("image_text_gap"), 10, 0, 40) + "px"));
		return mobileCard;
	}

	function buildRootBranch(row) {
		var card = row.children(".kidia-category-card");
		var editorChildren = row.children(".kidia-category-children");
		var branch;
		var tile;
		var childrenContainer;
		var visibleChildren = 0;

		if (isHidden(card)) {
			return null;
		}

		branch = $('<section class="kidia-category-preview-branch"></section>').attr("data-term-id", row.attr("data-term-id") || "");
		tile = $('<div class="kidia-category-preview-root"></div>');
		tile.append(buildArtwork(card, 78));
		tile.append(buildCategoryName(row, card, false).css("margin-right", numberInRange(setting("image_text_gap"), 10, 0, 40) + "px"));
		if (String(setting("show_arrow")) !== "0") {
			tile.append(editorChildren.length ? '<button type="button" class="kidia-category-preview-expand" aria-label="Toggle subcategories"><span>⌄</span></button>' : '<span class="kidia-category-preview-chevron">‹</span>');
		}
		branch.append(tile);

		if (editorChildren.length && isRowExpanded(row)) {
			childrenContainer = $('<div class="kidia-category-preview-children"></div>');
			editorChildren.children(".kidia-category-list").first().children(".kidia-category-row").each(function () {
				var child = buildChildCard($(this));
				if (child) {
					childrenContainer.append(child);
					visibleChildren += 1;
				}
			});
			if (visibleChildren) {
				branch.addClass("is-expanded").append(childrenContainer);
			}
		}
		return branch;
	}

	function renderChrome(part) {
		var card = builder.find('[data-chrome-part="' + part + '"]').first();
		if (window.KidiaChromePreview) {
			return part === "header"
				? window.KidiaChromePreview.renderHeader(card.get(0), "الأقسام", { collapsed: previewScrolled, page: "category" })
				: window.KidiaChromePreview.renderFooter(card.get(0), { page: "category" });
		}
		return "";
	}

	function renderMobilePreview() {
		var rootList = categoryElement.find(".kidia-category-items > .kidia-category-list").first();
		var layout = categoryLayout();
		var columns = numberInRange(setting("grid_columns"), 2, 2, 4);
		var content = $('<div class="kidia-category-preview-content"></div>').addClass("is-layout-" + layout).css({"--category-columns": columns, "--category-card-gap": numberInRange(setting("card_gap"), 10, 0, 24) + "px", "--category-card-radius": numberInRange(setting("card_radius"), 17, 0, 32) + "px"});
		var visible = 0;
		preview.empty().append(renderChrome("header"));

		if (elementEnabled()) {
			if (layout === "sidebar") {
				var sidebar = $('<div class="kidia-category-preview-sidebar"></div>');
				var detail = $('<div class="kidia-category-preview-sidebar-detail"></div>');
				var firstVisible = null;
				rootList.children(".kidia-category-row").each(function () {
					var row = $(this), card = row.children(".kidia-category-card");
					if (isHidden(card)) { return; }
					if (!firstVisible) { firstVisible = row; }
					sidebar.append(buildCategoryName(row, card, false).addClass("kidia-category-preview-sidebar-root"));
					visible += 1;
				});
				if (firstVisible) {
					var childRows = firstVisible.children(".kidia-category-children").find("> .kidia-category-list > .kidia-category-row");
					if (childRows.length) { childRows.each(function () { var child = buildChildCard($(this)); if (child) { detail.append(child); } }); }
					else { detail.append(buildArtwork(firstVisible.children(".kidia-category-card"), 82)).append(buildCategoryName(firstVisible, firstVisible.children(".kidia-category-card"), false)); }
				}
				content.append(sidebar, detail);
			} else rootList.children(".kidia-category-row").each(function () {
				var branch = buildRootBranch($(this));
				if (branch) {
					content.append(branch);
					visible += 1;
				}
			});
		}

		if (!visible) {
			content.append('<div class="kidia-category-preview-empty">' + (elementEnabled() ? "No visible categories." : "Category element is hidden.") + "</div>");
		}
		preview.append(content).append(renderChrome("footer"));
		categoryElement.toggleClass("is-enabled", elementEnabled());
	}

	function updateRangeLabel(input) {
		var name = input.name || "";
		var display = input.value + "px";
		if (name.indexOf("image_scale") !== -1 || name.indexOf("image_radius") !== -1) {
			display = input.value + "%";
		} else if (name.indexOf("line_height") !== -1) {
			display = (Number(input.value) / 100).toFixed(2);
		}
		$(input).siblings(".kidia-range-value").text(display);
	}

	builder.on("click", ".kidia-fixed-chrome-expand, .kidia-category-element-expand", function () {
		var button = $(this);
		var card = button.closest(".kidia-page-card");
		var body = card.children(".kidia-page-card__body").first();
		var opening = body.prop("hidden");
		body.prop("hidden", !opening);
		button.attr("aria-expanded", opening ? "true" : "false");
		card.toggleClass("is-open", opening);
	});

	if ($.fn && typeof $.fn.sortable === "function") {
		builder.find(".kidia-category-list").each(function () {
			$(this).sortable({
				items: "> .kidia-category-row",
				handle: ".kidia-category-handle",
				axis: "y",
				containment: "parent",
				update: function () {
					updateOrders(this);
					markDirty();
					renderMobilePreview();
				}
			});
		});
	}

	builder.on("click", ".kidia-category-expand", function () {
		var row = $(this).closest(".kidia-category-row");
		setRowExpanded(row, !isRowExpanded(row));
		renderMobilePreview();
	});

	builder.on("click", ".kidia-category-preview-expand", function () {
		var termId = $(this).closest(".kidia-category-preview-branch").attr("data-term-id");
		var row = builder.find('.kidia-category-row[data-term-id="' + termId + '"]').first();
		if (row.length) {
			setRowExpanded(row, !isRowExpanded(row));
			renderMobilePreview();
		}
	});

	builder.on("input change", ".kidia-category-general input, .kidia-category-general select", function () {
		if (String(this.type).toLowerCase() === "range") {
			updateRangeLabel(this);
		}
		builder.find(".kidia-category-card").each(function () { updateEditorArtwork($(this)); });
		renderMobilePreview();
	});

	builder.on("input change", ".kidia-category-name-input, .kidia-category-visibility input, .kidia-category-element-enabled", renderMobilePreview);
	builder.on("input change", ".kidia-fixed-chrome-card input, .kidia-fixed-chrome-card select", renderMobilePreview);

	builder.on("click", ".kidia-category-image-button", function () {
		var card = $(this).closest(".kidia-category-card");
		var frame;
		if (!window.wp || !window.wp.media) {
			return;
		}
		frame = window.wp.media({ title: "Choose category image", button: { text: "Use image" }, multiple: false });
		frame.on("select", function () {
			var selected = frame.state().get("selection").first();
			var image = selected ? selected.toJSON() : null;
			var source;
			if (!image || !image.url) {
				return;
			}
			source = image.sizes && image.sizes.thumbnail ? image.sizes.thumbnail.url : image.url;
			card.find(".kidia-category-image-id").val(image.id || 0);
			card.find(".kidia-category-image").empty().append($("<img>", { src: source, alt: "" }));
			card.find(".kidia-category-image-clear").prop("hidden", false);
			updateEditorArtwork(card);
			markDirty();
			renderMobilePreview();
		});
		frame.open();
	});

	builder.on("click", ".kidia-category-image-clear", function () {
		var button = $(this);
		var card = button.closest(".kidia-category-card");
		var fallback = card.closest(".kidia-category-row").attr("data-default-image") || "";
		card.find(".kidia-category-image-id").val("0");
		card.find(".kidia-category-image").empty().append(fallback ? $("<img>", { src: fallback, alt: "" }) : '<span class="dashicons dashicons-format-image"></span>');
		button.prop("hidden", true);
		updateEditorArtwork(card);
		markDirty();
		renderMobilePreview();
	});

	if (phoneScreen) {
		phoneScreen.addEventListener("scroll", function () {
			var next = phoneScreen.scrollTop > 1;
			if (next !== previewScrolled) {
				previewScrolled = next;
				renderMobilePreview();
			}
		}, { passive: true });
	}

	builder.find(".kidia-category-row").each(function () {
		var row = $(this);
		var button = row.children(".kidia-category-card").find(".kidia-category-expand").first();
		if (button.length) {
			setRowExpanded(row, button.attr("aria-expanded") === "true");
		}
	});
	builder.find(".kidia-category-card").each(function () { updateEditorArtwork($(this)); });
	renderMobilePreview();
}());
