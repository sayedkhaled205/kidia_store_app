(() => {
  (function($) {
    "use strict";
    function updateOrders(list) {
      $(list).children(".kidia-category-row").each(function(index) {
        $(this).children(".kidia-category-card").find(".kidia-category-order").val(index);
      });
    }
    function setting(card, suffix) {
      return card.find('[name$="[' + suffix + ']"]').val();
    }
    function updatePreview(card) {
      const preview = card.find(".kidia-category-image");
      const image = preview.find("img");
      const size = Math.min(72, Number(setting(card, "image_size")) || 68);
      const shape = setting(card, "image_shape") || "rounded";
      const radius = Number(setting(card, "image_radius")) || 0;
      const position = setting(card, "image_position") || "center";
      const positions = { center: "center", top: "center top", bottom: "center bottom", left: "left center", right: "right center" };
      preview.css({
        width: size + "px",
        height: size + "px",
        borderRadius: shape === "circle" ? "50%" : shape === "rounded" ? radius + "%" : "0",
        border: (Number(setting(card, "border_width")) || 0) + "px solid " + (setting(card, "border_color") || "#DDE5E2"),
        backgroundColor: setting(card, "background_color") || "#FFFFFF",
        boxShadow: setting(card, "image_effect") === "shadow" ? "0 4px 10px rgba(0,0,0,.2)" : "none"
      });
      image.css({
        objectFit: setting(card, "image_fit") || "contain",
        objectPosition: positions[position] || "center",
        transform: "scale(" + (Number(setting(card, "image_scale")) || 100) / 100 + ")",
        filter: setting(card, "image_effect") === "grayscale" ? "grayscale(1)" : "none"
      });
      card.find(".kidia-category-name").css(
        "margin-right",
        (Number(setting(card, "image_text_gap")) || 0) + "px"
      );
      card.find(".kidia-category-name strong").css({
        fontSize: (Number(setting(card, "font_size")) || 16) + "px",
        color: setting(card, "font_color") || "#1F2933",
        fontWeight: setting(card, "font_weight") || "800",
        textAlign: setting(card, "text_align") || "start",
        lineHeight: (Number(setting(card, "line_height")) || 125) / 100,
        display: "-webkit-box",
        WebkitBoxOrient: "vertical",
        WebkitLineClamp: setting(card, "text_max_lines") || "2",
        overflow: "hidden"
      });
    }
    function renderMobilePreview() {
      const preview = $("#kidia-category-live-preview");
      if (!preview.length) return;
      preview.empty();
      function renderList(list, depth) {
        list.children(".kidia-category-row").each(function() {
          const row = $(this);
          const card = row.children(".kidia-category-card");
          if (card.find('.kidia-category-visibility input[type="checkbox"]').is(":checked")) return;
          const sourceImage = card.find(".kidia-category-image img").attr("src") || "";
          const size = Math.min(92, Math.max(28, Number(setting(card, "image_size")) || 68));
          const shape = setting(card, "image_shape") || "rounded";
          const radius = Number(setting(card, "image_radius")) || 0;
          const imageBox = $('<div class="kidia-category-preview-image"></div>').css({
            width: size + "px",
            height: size + "px",
            borderRadius: shape === "circle" ? "50%" : shape === "rounded" ? radius + "%" : "0",
            border: (Number(setting(card, "border_width")) || 0) + "px solid " + (setting(card, "border_color") || "#DDE5E2"),
            backgroundColor: setting(card, "background_color") || "#FFFFFF",
            boxShadow: setting(card, "image_effect") === "shadow" ? "0 4px 10px rgba(0,0,0,.2)" : "none"
          });
          if (sourceImage) {
            imageBox.append($('<img alt="">').attr("src", sourceImage).css({
              objectFit: setting(card, "image_fit") || "contain",
              objectPosition: setting(card, "image_position") || "center",
              transform: "scale(" + (Number(setting(card, "image_scale")) || 100) / 100 + ")",
              filter: setting(card, "image_effect") === "grayscale" ? "grayscale(1)" : "none"
            }));
          } else {
            imageBox.append('<span class="dashicons dashicons-format-image kidia-category-preview-placeholder"></span>');
          }
          const mobileCard = $('<div class="kidia-category-preview-card"></div>');
          if (depth > 0) mobileCard.addClass("is-child");
          const name = $('<div class="kidia-category-preview-name"></div>').text(row.data("term-name") || card.find(".kidia-category-name strong").text()).css({
            fontSize: (Number(setting(card, "font_size")) || 16) + "px",
            color: setting(card, "font_color") || "#1F2933",
            fontWeight: setting(card, "font_weight") || "800",
            textAlign: setting(card, "text_align") || "center",
            lineHeight: (Number(setting(card, "line_height")) || 125) / 100,
            display: "-webkit-box",
            WebkitBoxOrient: "vertical",
            WebkitLineClamp: setting(card, "text_max_lines") || "2"
          });
          mobileCard.css("--preview-gap", (Number(setting(card, "image_text_gap")) || 0) + "px").append(imageBox, name);
          preview.append(mobileCard);
          const children = row.children(".kidia-category-children");
          if (children.length && !children.prop("hidden")) renderList(children.children(".kidia-category-list"), depth + 1);
        });
      }
      renderList($(".kidia-category-editor form > .kidia-category-list"), 0);
      if (!preview.children().length) preview.append('<div class="kidia-category-preview-empty">No visible categories.</div>');
    }
    $(".kidia-category-list").each(function() {
      $(this).sortable({
        items: "> .kidia-category-row",
        handle: ".kidia-category-handle",
        axis: "y",
        containment: "parent",
        update: function() {
          updateOrders(this);
          renderMobilePreview();
        }
      });
    });
    $(".kidia-category-expand").on("click", function() {
      const button = $(this);
      const row = button.closest(".kidia-category-row");
      const children = row.children(".kidia-category-children");
      const expanded = button.attr("aria-expanded") === "true";
      button.attr("aria-expanded", String(!expanded));
      children.prop("hidden", expanded);
      renderMobilePreview();
    });
    $(".kidia-category-settings-toggle").on("click", function() {
      const button = $(this);
      const panel = button.closest(".kidia-category-card").find(".kidia-category-settings");
      const expanded = button.attr("aria-expanded") === "true";
      button.attr("aria-expanded", String(!expanded));
      panel.prop("hidden", expanded);
    });
    $('.kidia-category-settings input[type="range"]').on("input", function() {
      let display = this.value + "px";
      if (this.name.includes("image_scale") || this.name.includes("image_radius")) {
        display = this.value + "%";
      } else if (this.name.includes("line_height")) {
        display = (Number(this.value) / 100).toFixed(2);
      }
      $(this).siblings(".kidia-range-value").text(display);
      updatePreview($(this).closest(".kidia-category-card"));
      renderMobilePreview();
    });
    $('.kidia-category-settings select, .kidia-category-settings input[type="number"], .kidia-category-settings input[type="color"]').on("input change", function() {
      updatePreview($(this).closest(".kidia-category-card"));
      renderMobilePreview();
    });
    $('.kidia-category-visibility input[type="checkbox"]').on("change", renderMobilePreview);
    $(".kidia-category-image-button").on("click", function() {
      const card = $(this).closest(".kidia-category-card");
      const frame = wp.media({ title: "Choose category image", button: { text: "Use image" }, multiple: false });
      frame.on("select", function() {
        var _a, _b;
        const image = frame.state().get("selection").first().toJSON();
        card.find(".kidia-category-image-id").val(image.id);
        card.find(".kidia-category-image").html($("<img>", { src: ((_b = (_a = image.sizes) == null ? void 0 : _a.thumbnail) == null ? void 0 : _b.url) || image.url, alt: "" }));
        card.find(".kidia-category-image-clear").prop("hidden", false);
        updatePreview(card);
        renderMobilePreview();
      });
      frame.open();
    });
    $(".kidia-category-image-clear").on("click", function() {
      const card = $(this).closest(".kidia-category-card");
      card.find(".kidia-category-image-id").val("0");
      const fallback = card.closest(".kidia-category-row").data("default-image") || "";
      card.find(".kidia-category-image").html(fallback ? $("<img>", { src: fallback, alt: "" }) : '<span class="dashicons dashicons-format-image"></span>');
      $(this).prop("hidden", true);
      updatePreview(card);
      renderMobilePreview();
    });
    $(".kidia-category-card").each(function() {
      updatePreview($(this));
    });
    renderMobilePreview();
  })(jQuery);
})();
