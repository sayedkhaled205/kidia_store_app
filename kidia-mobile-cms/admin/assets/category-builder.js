(function () {
	"use strict";

	if (!window.jQuery) {
		return;
	}

	var $ = window.jQuery;
	var builder = $(".kidia-category-builder").first();
	var preview = $("#kidia-category-live-preview");
	var expandedTerms = {};

	if (!builder.length || !preview.length) {
		return;
	}

	window.kidiaCategoryBuilderBooted = true;

	builder.on("click", ".kidia-fixed-chrome-expand", function () {
		var button = $(this);
		var card = button.closest(".kidia-fixed-chrome-card");
		var body = card.find(".kidia-page-card__body").first();
		var opening = body.prop("hidden");
		body.prop("hidden", !opening);
		button.attr("aria-expanded", opening ? "true" : "false");
		card.toggleClass("is-open", opening);
	});

	function numberInRange(value, fallback, minimum, maximum) {
		var number = Number(value);
		if (!isFinite(number)) {
			number = fallback;
		}
		return Math.max(minimum, Math.min(maximum, number));
	}

	function setting(card, suffix) {
		var field = card.find('[name$="[' + suffix + ']"]').first();
		return field.length ? field.val() : "";
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
		var button;

		if (key && Object.prototype.hasOwnProperty.call(expandedTerms, key)) {
			return expandedTerms[key];
		}

		button = row.children(".kidia-category-card").find(".kidia-category-expand").first();
		return button.attr("aria-expanded") === "true";
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

	function applyArtworkStyles(box, image, card, maximumSize) {
		var size = numberInRange(setting(card, "image_size"), 68, 32, maximumSize);
		var shape = setting(card, "image_shape") || "rounded";
		var radius = numberInRange(setting(card, "image_radius"), 18, 0, 50);
		var effect = setting(card, "image_effect") || "none";

		box.css({
			width: size + "px",
			height: size + "px",
			borderRadius: shape === "circle" ? "50%" : shape === "rounded" ? radius + "%" : "0",
			border: numberInRange(setting(card, "border_width"), 0, 0, 8) + "px solid " + (setting(card, "border_color") || "#DDE5E2"),
			backgroundColor: setting(card, "background_color") || "#FFFFFF",
			boxShadow: effect === "shadow" ? "0 4px 10px rgba(0,0,0,.2)" : "none"
		});

		image.css({
			objectFit: setting(card, "image_fit") || "contain",
			objectPosition: imagePosition(setting(card, "image_position")),
			transform: "scale(" + numberInRange(setting(card, "image_scale"), 100, 80, 150) / 100 + ")",
			filter: effect === "grayscale" ? "grayscale(1)" : "none"
		});
	}

	function applyNameStyles(name, card, isChild) {
		var requestedSize = numberInRange(setting(card, "font_size"), 16, 10, 30);
		var displaySize = isChild ? Math.min(requestedSize, 14) : Math.min(requestedSize, 18);

		name.css({
			fontSize: displaySize + "px",
			color: setting(card, "font_color") || "#1F2933",
			fontWeight: setting(card, "font_weight") || "800",
			textAlign: textAlignment(setting(card, "text_align")),
			lineHeight: numberInRange(setting(card, "line_height"), 125, 100, 200) / 100,
			display: "-webkit-box",
			WebkitBoxOrient: "vertical",
			WebkitLineClamp: String(numberInRange(setting(card, "text_max_lines"), 2, 1, 3)),
			overflow: "hidden"
		});
	}

	function updateEditorCard(card) {
		var artwork = card.find(".kidia-category-image").first();
		var image = artwork.find("img");
		var name = card.find(".kidia-category-name strong").first();

		applyArtworkStyles(artwork, image, card, 72);
		card.find(".kidia-category-name").css("margin-right", numberInRange(setting(card, "image_text_gap"), 10, 0, 40) + "px");
		applyNameStyles(name, card, false);
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

		applyArtworkStyles(box, image, card, maximumSize);
		return box;
	}

	function buildCategoryName(row, card, isChild) {
		var name = $('<div class="kidia-category-preview-name"></div>');
		name.text(row.attr("data-term-name") || card.find(".kidia-category-name strong").text());
		applyNameStyles(name, card, isChild);
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
		mobileCard.append(buildCategoryName(row, card, true).css("margin-top", numberInRange(setting(card, "image_text_gap"), 10, 0, 40) + "px"));
		return mobileCard;
	}

	function buildRootBranch(row) {
		var card = row.children(".kidia-category-card");
		var branch;
		var tile;
		var childrenContainer;
		var editorChildren;
		var childrenList;
		var visibleChildren = 0;

		if (isHidden(card)) {
			return null;
		}

		branch = $('<section class="kidia-category-preview-branch"></section>').attr("data-term-id", row.attr("data-term-id") || "");
		tile = $('<div class="kidia-category-preview-root"></div>');
		tile.append(buildArtwork(card, 78));
		tile.append(buildCategoryName(row, card, false).css("margin-right", numberInRange(setting(card, "image_text_gap"), 10, 0, 40) + "px"));

		editorChildren = row.children(".kidia-category-children");
		if (editorChildren.length) {
			tile.append('<button type="button" class="kidia-category-preview-expand" aria-label="Toggle subcategories"><span>⌄</span></button>');
		} else {
			tile.append('<span class="kidia-category-preview-chevron">‹</span>');
		}

		branch.append(tile);

		if (editorChildren.length && isRowExpanded(row)) {
			childrenContainer = $('<div class="kidia-category-preview-children"></div>');
			childrenList = editorChildren.children(".kidia-category-list").first();
			childrenList.children(".kidia-category-row").each(function () {
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

	function renderMobilePreview() {
		var rootList = builder.find(".kidia-category-editor form > .kidia-category-list").first();
		var visible = 0;

		preview.empty();
		rootList.children(".kidia-category-row").each(function () {
			var branch;
			try {
				branch = buildRootBranch($(this));
				if (branch) {
					preview.append(branch);
					visible += 1;
				}
			} catch (error) {
				if (window.console && window.console.error) {
					window.console.error("Kidia category preview skipped a malformed category.", error);
				}
			}
		});

		if (!visible) {
			preview.append('<div class="kidia-category-preview-empty">No visible categories.</div>');
		}
	}

	function updateRangeLabel(input) {
		var value = input.value;
		var name = input.name || "";
		var display = value + "px";

		if (name.indexOf("image_scale") !== -1 || name.indexOf("image_radius") !== -1) {
			display = value + "%";
		} else if (name.indexOf("line_height") !== -1) {
			display = (Number(value) / 100).toFixed(2);
		}

		$(input).siblings(".kidia-range-value").text(display);
	}

	if ($.fn && typeof $.fn.sortable === "function") {
		builder.find(".kidia-category-list").each(function () {
			$(this).sortable({
				items: "> .kidia-category-row",
				handle: ".kidia-category-handle",
				axis: "y",
				containment: "parent",
				update: function () {
					updateOrders(this);
					renderMobilePreview();
				}
			});
		});
	}

	builder.on("click", ".kidia-category-expand", function () {
		var button = $(this);
		var row = button.closest(".kidia-category-row");

		setRowExpanded(row, !isRowExpanded(row));
		renderMobilePreview();
	});

	builder.on("click", ".kidia-category-preview-expand", function () {
		var branch = $(this).closest(".kidia-category-preview-branch");
		var termId = branch.attr("data-term-id");
		var row = builder.find(".kidia-category-row").filter(function () {
			return String($(this).attr("data-term-id") || "") === String(termId || "");
		}).first();

		if (!row.length) {
			return;
		}

		setRowExpanded(row, !isRowExpanded(row));
		renderMobilePreview();
	});

	builder.on("click", ".kidia-category-settings-toggle", function () {
		var button = $(this);
		var panel = button.closest(".kidia-category-card").find(".kidia-category-settings").first();
		var expanded = button.attr("aria-expanded") === "true";

		button.attr("aria-expanded", String(!expanded));
		panel.prop("hidden", expanded);
	});

	builder.on("input change", ".kidia-category-settings input, .kidia-category-settings select", function () {
		var card = $(this).closest(".kidia-category-card");
		if (String(this.type).toLowerCase() === "range") {
			updateRangeLabel(this);
		}
		updateEditorCard(card);
		renderMobilePreview();
	});

	builder.on("change", '.kidia-category-visibility input[type="checkbox"]', function () {
		renderMobilePreview();
	});

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
			updateEditorCard(card);
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
		updateEditorCard(card);
		renderMobilePreview();
	});

	builder.find(".kidia-category-row").each(function () {
		var row = $(this);
		var button = row.children(".kidia-category-card").find(".kidia-category-expand").first();

		if (button.length) {
			setRowExpanded(row, button.attr("aria-expanded") === "true");
		}
	});

	builder.find(".kidia-category-card").each(function () {
		try {
			updateEditorCard($(this));
		} catch (error) {
			if (window.console && window.console.error) {
				window.console.error("Kidia category editor skipped a malformed category.", error);
			}
		}
	});

	renderMobilePreview();
}());
