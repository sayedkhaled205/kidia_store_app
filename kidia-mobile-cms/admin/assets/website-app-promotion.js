(() => {
  "use strict";

  const admin = document.querySelector("[data-promotion-admin]");
  if (!admin) return;

  const form = admin.querySelector("[data-promotion-form]");
  const preview = admin.querySelector("[data-promotion-preview]");
  const output = admin.querySelector("[data-preview-output]");
  const campaignLabel = admin.querySelector("[data-preview-campaign-label]");
  const typeCards = [...admin.querySelectorAll("[data-promotion-type]")];
  const panels = [...admin.querySelectorAll("[data-promotion-campaign-panel]")];
  let selectedCampaign = "smart_banner";

  const fieldValue = (name, fallback = "") => {
    const control = form.elements.namedItem(name);
    return control ? String(control.value || fallback) : fallback;
  };
  const create = (tag, className, text) => {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  };
  const setDevice = (device) => {
    preview.classList.toggle("is-mobile", device === "mobile");
    preview.classList.toggle("is-desktop", device === "desktop");
    admin.querySelectorAll("[data-preview-device]").forEach((button) => {
      button.classList.toggle("is-active", button.dataset.previewDevice === device);
    });
  };
  const selectCampaign = (key) => {
    selectedCampaign = key;
    typeCards.forEach((card) =>
      card.classList.toggle("is-selected", card.dataset.promotionType === key),
    );
    panels.forEach((panel) => {
      const active = panel.dataset.promotionCampaignPanel === key;
      panel.hidden = !active;
      panel.classList.toggle("is-active", active);
    });
    const card = typeCards.find((item) => item.dataset.promotionType === key);
    campaignLabel.textContent =
      card?.querySelector("strong")?.textContent || "Campaign";
    if (key === "desktop_qr") setDevice("desktop");
    if (key === "bottom_sheet") setDevice("mobile");
    renderPreview();
  };

  const renderPreview = () => {
    output.replaceChildren();
    const appName = fieldValue("promotion[app_name]", "Your app");
    const tagline = fieldValue(
      "promotion[tagline]",
      "Shop faster in the app",
    );
    const offer = fieldValue("promotion[offer_text]");
    const coupon = fieldValue("promotion[coupon_code]");
    const logoUrl = fieldValue("promotion[logo_url]");
    const buttonLabel = fieldValue(
      "promotion[button_label]",
      "Download app",
    );
    const primary = fieldValue("promotion[primary_color]", "#2f806e");
    const ink = fieldValue("promotion[text_color]", "#15352d");
    const surface = fieldValue("promotion[surface_color]", "#ffffff");
    const promo = create(
      "div",
      `kidia-preview-promo is-${selectedCampaign}`,
    );
    promo.style.setProperty("--brand", primary);
    promo.style.setProperty("--ink", ink);
    promo.style.setProperty("--surface", surface);
    if (
      selectedCampaign === "smart_banner" &&
      fieldValue("promotion[smart_banner][position]") === "bottom"
    ) {
      promo.classList.add("is-bottom");
    }

    const logo = create("span", "kidia-preview-promo__logo");
    if (logoUrl) {
      const image = create("img");
      image.src = logoUrl;
      image.alt = "";
      logo.append(image);
    } else {
      logo.textContent = appName.trim().slice(0, 1).toUpperCase() || "A";
    }
    promo.append(logo);

    if (selectedCampaign === "desktop_qr") {
      const qr = create("span", "kidia-preview-promo__qr");
      promo.append(qr);
      const qrText =
        fieldValue("promotion[qr_url]") ||
        fieldValue("promotion[smart_url]") ||
        fieldValue("promotion[android_url]") ||
        fieldValue("promotion[ios_url]") ||
        "https://example.com/app";
      if (window.QRCode) {
        new window.QRCode(qr, {
          text: qrText,
          width: 55,
          height: 55,
          colorDark: ink,
          colorLight: surface,
          correctLevel: window.QRCode.CorrectLevel.M,
        });
      }
    }

    const copy = create("span", "kidia-preview-promo__copy");
    copy.append(create("strong", "", appName));
    copy.append(
      create(
        "small",
        "",
        offer ? `${offer}${coupon ? ` · ${coupon}` : ""}` : tagline,
      ),
    );
    promo.append(copy);

    if (!["floating_button"].includes(selectedCampaign)) {
      promo.append(
        create("span", "kidia-preview-promo__button", buttonLabel),
      );
      promo.append(create("span", "kidia-preview-promo__close", "×"));
    }
    output.append(promo);
    const storeName = admin.querySelector("[data-preview-store-name]");
    if (storeName) storeName.textContent = appName;
  };

  typeCards.forEach((card) => {
    const choose = (event) => {
      if (event.type === "keydown" && !["Enter", " "].includes(event.key)) {
        return;
      }
      if (event.type === "keydown") event.preventDefault();
      selectCampaign(card.dataset.promotionType);
    };
    card.addEventListener("click", choose);
    card.addEventListener("keydown", choose);
    const toggle = card.querySelector('input[type="checkbox"]');
    toggle?.addEventListener("change", () => {
      card.classList.toggle("is-enabled", toggle.checked);
    });
  });

  admin.querySelectorAll("[data-preview-device]").forEach((button) => {
    button.addEventListener("click", () => setDevice(button.dataset.previewDevice));
  });

  form.addEventListener("input", renderPreview);
  form.addEventListener("change", (event) => {
    if (event.target.matches("[data-page-target]")) {
      const custom = admin.querySelector("[data-custom-paths]");
      custom.hidden = event.target.value !== "custom";
    }
    renderPreview();
  });

  const master = admin.querySelector("[data-promotion-master]");
  const masterLabel = admin.querySelector("[data-promotion-master-label]");
  const state = admin.querySelector(".kidia-app-promotion-state");
  master?.addEventListener("change", () => {
    masterLabel.textContent = master.checked ? "On" : "Off";
    state?.classList.toggle("is-live", master.checked);
    if (state) {
      state.lastChild.textContent = master.checked
        ? "Campaigns live"
        : "Campaigns paused";
    }
  });

  admin.querySelector("[data-promotion-media]")?.addEventListener("click", () => {
    if (!window.wp?.media) return;
    const frame = window.wp.media({
      title: "Choose app icon",
      button: { text: "Use this icon" },
      multiple: false,
      library: { type: "image" },
    });
    frame.on("select", () => {
      const attachment = frame.state().get("selection").first()?.toJSON();
      const input = form.elements.namedItem("promotion[logo_url]");
      if (attachment?.url && input) {
        input.value = attachment.url;
        input.dispatchEvent(new Event("input", { bubbles: true }));
      }
    });
    frame.open();
  });

  admin.querySelector("[data-copy-shortcode]")?.addEventListener("click", async (event) => {
    const button = event.currentTarget;
    try {
      await navigator.clipboard.writeText("[woo_mobile_app_promo]");
      button.textContent = "Copied";
    } catch (_error) {
      button.textContent = "Copy failed";
    }
    window.setTimeout(() => {
      button.textContent = "Copy";
    }, 1500);
  });

  selectCampaign(selectedCampaign);
})();
