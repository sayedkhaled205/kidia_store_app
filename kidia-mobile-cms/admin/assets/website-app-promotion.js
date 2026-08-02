(() => {
  "use strict";

  const initializePromotionAdmin = () => {
    const admin = document.querySelector("[data-promotion-admin]");
    if (!admin || admin.dataset.promotionPreviewInitialized === "true") return;
    admin.dataset.promotionPreviewInitialized = "true";

    const form = admin.querySelector("[data-promotion-form]");
    const preview = admin.querySelector("[data-promotion-preview]");
    const previewScreen = admin.querySelector("[data-promotion-screen]");
    const previewBrowser = admin.querySelector("[data-promotion-browser]");
    const output = admin.querySelector("[data-preview-output]");
    const campaignLabel = admin.querySelector("[data-preview-campaign-label]");
    const typeCards = [...admin.querySelectorAll("[data-promotion-type]")];
    const panels = [...admin.querySelectorAll("[data-promotion-campaign-panel]")];
    const master = admin.querySelector("[data-promotion-master]");
    const masterLabel = admin.querySelector("[data-promotion-master-label]");
    const state = admin.querySelector(".kidia-app-promotion-state");
    const stateLabel = admin.querySelector("[data-promotion-state-label]");
    let selectedCampaign = "smart_banner";
    let selectedDevice = "desktop";
    const previewSizes = {
      mobile: { width: 390, height: 844 },
      desktop: { width: 1366, height: 768 },
    };
    const statusLabels = {
      live: "Live",
      announcement: "Announcement live",
      "needs-link": "Needs app link",
      "needs-placement": "Needs placement",
      paused: "Paused",
    };

    const field = (name) => form?.elements.namedItem(name) || null;
    const fieldValue = (name, fallback = "") => {
      const control = field(name);
      return control ? String(control.value || fallback) : fallback;
    };
    const fieldChecked = (name) => Boolean(field(name)?.checked);
    const create = (tag, className, text) => {
      const node = document.createElement(tag);
      if (className) node.className = className;
      if (text !== undefined) node.textContent = text;
      return node;
    };
    const destination = () =>
      fieldValue("promotion[smart_url]") ||
      fieldValue("promotion[android_url]") ||
      fieldValue("promotion[ios_url]") ||
      fieldValue("promotion[huawei_url]") ||
      fieldValue("promotion[deep_link]") ||
      fieldValue("promotion[qr_url]");
    const campaignStatus = (key) => {
      if (
        !master?.checked ||
        !fieldChecked(`promotion[${key}][enabled]`)
      ) {
        return "paused";
      }
      if (
        key === "inline_banner" &&
        fieldValue("promotion[inline_banner][placement]") === "shortcode"
      ) {
        return "needs-placement";
      }
      return destination() ? "live" : "announcement";
    };
    const updateCampaignStatuses = () => {
      let liveCount = 0;
      typeCards.forEach((card) => {
        const key = card.dataset.promotionType;
        const status = campaignStatus(key);
        const statusNode = card.querySelector("[data-promotion-status]");
        card.dataset.promotionStatus = status;
        card.classList.toggle(
          "is-enabled",
          status === "live" || status === "announcement",
        );
        if (statusNode) {
          statusNode.className = `kidia-app-promotion-type__status is-${status}`;
          statusNode.textContent = statusLabels[status];
        }
        if (["live", "announcement"].includes(status)) liveCount += 1;
      });
      if (stateLabel) {
        stateLabel.textContent = master?.checked
          ? `${liveCount} campaigns live`
          : "Campaigns paused";
      }
    };
    const updateMasterState = () => {
      if (!master) return;
      if (masterLabel) masterLabel.textContent = master.checked ? "On" : "Off";
      state?.classList.toggle("is-live", master.checked);
      updateCampaignStatuses();
    };
    const resizePreview = () => {
      if (!previewScreen || !previewBrowser || !preview) return;
      const size = previewSizes[selectedDevice];
      const computed = window.getComputedStyle(preview);
      const horizontalPadding =
        parseFloat(computed.paddingLeft || "0") +
        parseFloat(computed.paddingRight || "0");
      const availableWidth = Math.max(
        240,
        preview.clientWidth - horizontalPadding,
      );
      const scale = Math.min(1, availableWidth / size.width);
      previewBrowser.style.setProperty("--preview-scale", String(scale));
      previewScreen.style.width = `${Math.round(size.width * scale)}px`;
      previewScreen.style.height = `${Math.round(size.height * scale)}px`;
    };
    const setDevice = (device) => {
      selectedDevice = device in previewSizes ? device : "desktop";
      preview?.classList.toggle("is-mobile", selectedDevice === "mobile");
      preview?.classList.toggle("is-desktop", selectedDevice === "desktop");
      admin.classList.toggle("is-desktop-preview", selectedDevice === "desktop");
      admin.querySelectorAll("[data-preview-device]").forEach((button) => {
        const active = button.dataset.previewDevice === selectedDevice;
        button.classList.toggle("is-active", active);
        button.setAttribute("aria-pressed", String(active));
      });
      resizePreview();
      window.requestAnimationFrame?.(resizePreview);
    };
    const appendQrPlaceholder = (holder) => {
      const placeholder = create("span", "kidia-app-promo__qr-placeholder");
      for (let index = 0; index < 25; index += 1) {
        placeholder.append(create("i"));
      }
      holder.classList.add("is-placeholder");
      holder.append(placeholder);
    };
    const renderPreview = () => {
      if (!output) return;
      output.replaceChildren();
      const appName = fieldValue("promotion[app_name]", "Your app");
      const tagline = fieldValue(
        "promotion[tagline]",
        "Shop faster in the app",
      );
      const description = fieldValue("promotion[description]");
      const offer = fieldValue("promotion[offer_text]");
      const coupon = fieldValue("promotion[coupon_code]");
      const logoUrl = fieldValue("promotion[logo_url]");
      const buttonLabel = fieldValue(
        "promotion[button_label]",
        "Download app",
      );
      const dismissLabel = fieldValue(
        "promotion[dismiss_label]",
        "Not now",
      );
      const primary = fieldValue("promotion[primary_color]", "#2f806e");
      const ink = fieldValue("promotion[text_color]", "#15352d");
      const surface = fieldValue("promotion[surface_color]", "#ffffff");
      const target =
        selectedCampaign === "desktop_qr"
          ? fieldValue("promotion[qr_url]") || destination()
          : destination();
      const promoTag = selectedCampaign === "floating_button" ? "button" : "section";
      const promo = create(
        promoTag,
        `kidia-app-promo kidia-app-promo--${selectedCampaign}`,
      );
      promo.dataset.kidiaAppPromotion = selectedCampaign;
      promo.style.setProperty("--kidia-app-promo-brand", primary);
      promo.style.setProperty("--kidia-app-promo-ink", ink);
      promo.style.setProperty("--kidia-app-promo-surface", surface);
      if (!target) promo.classList.add("is-unlinked");
      if (selectedCampaign === "floating_button") promo.type = "button";

      const optionPrefix = `promotion[${selectedCampaign}]`;
      const position = fieldValue(`${optionPrefix}[position]`);
      const style = fieldValue(`${optionPrefix}[style]`);
      if (position) promo.classList.add(`is-${position}`);
      if (style) promo.classList.add(`is-${style}`);

      const logo = create("span", "kidia-app-promo__icon");
      if (logoUrl) {
        const image = create("img");
        image.src = logoUrl;
        image.alt = "";
        logo.append(image);
      } else {
        logo.classList.add("is-fallback");
        logo.append(create("span", "kidia-app-promo__phone-icon"));
      }
      promo.append(logo);

      const copy = create("span", "kidia-app-promo__copy");
      copy.append(
        create(
          "strong",
          "",
          selectedCampaign === "floating_button"
            ? fieldValue("promotion[floating_button][label]", appName)
            : appName,
        ),
      );
      if (selectedCampaign !== "floating_button") {
        copy.append(create("span", "kidia-app-promo__tagline", tagline));
        if (
          ["bottom_sheet", "popup", "inline_banner"].includes(
            selectedCampaign,
          ) &&
          description &&
          description !== tagline
        ) {
          copy.append(
            create("span", "kidia-app-promo__description", description),
          );
        }
        if (offer || coupon) {
          const offerNode = create(
            "small",
            "kidia-app-promo__offer",
            offer || "Coming soon",
          );
          if (coupon) {
            offerNode.append(
              create("b", "kidia-app-promo__coupon", coupon),
            );
          }
          copy.append(offerNode);
        } else if (!target) {
          copy.append(
            create("small", "kidia-app-promo__status", "Coming soon"),
          );
        }
      }
      promo.append(copy);

      if (selectedCampaign === "desktop_qr") {
        const qr = create("span", "kidia-app-promo__qr");
        if (target && window.QRCode) {
          new window.QRCode(qr, {
            text: target,
            width: 96,
            height: 96,
            colorDark: ink,
            colorLight: "#ffffff",
            correctLevel: window.QRCode.CorrectLevel.M,
          });
        } else {
          appendQrPlaceholder(qr);
        }
        promo.append(qr);
      }
      if (target && selectedCampaign !== "floating_button") {
        promo.append(create("a", "kidia-app-promo__action", buttonLabel));
      }
      if (["bottom_sheet", "popup"].includes(selectedCampaign)) {
        promo.append(
          create("button", "kidia-app-promo__later", dismissLabel),
        );
      }
      if (!["floating_button", "inline_banner"].includes(selectedCampaign)) {
        promo.append(create("button", "kidia-app-promo__dismiss", "×"));
      }
      if (selectedCampaign === "popup") {
        output.append(create("div", "kidia-app-promo-backdrop"));
      }
      output.append(promo);

      const storeName = admin.querySelector("[data-preview-store-name]");
      if (storeName) storeName.textContent = appName;
    };
    const selectCampaign = (key) => {
      selectedCampaign = key;
      typeCards.forEach((card) =>
        card.classList.toggle(
          "is-selected",
          card.dataset.promotionType === key,
        ),
      );
      panels.forEach((panel) => {
        const active = panel.dataset.promotionCampaignPanel === key;
        panel.hidden = !active;
        panel.classList.toggle("is-active", active);
      });
      const card = typeCards.find((item) => item.dataset.promotionType === key);
      if (campaignLabel) {
        campaignLabel.textContent =
          card?.querySelector("strong")?.textContent || "Campaign";
      }
      if (key === "desktop_qr") setDevice("desktop");
      if (key === "bottom_sheet") setDevice("mobile");
      renderPreview();
    };

    typeCards.forEach((card) => {
      const choose = (event) => {
        if (event.target.closest?.("[data-test-campaign]")) return;
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
        if (toggle.checked && master && !master.checked) {
          master.checked = true;
          updateMasterState();
        }
        updateCampaignStatuses();
      });
    });

    admin.querySelectorAll("[data-preview-device]").forEach((button) => {
      button.addEventListener("click", () =>
        setDevice(button.dataset.previewDevice),
      );
    });
    if ("ResizeObserver" in window && preview) {
      new window.ResizeObserver(resizePreview).observe(preview);
    }
    window.addEventListener("resize", resizePreview);

    form?.addEventListener("input", () => {
      renderPreview();
      updateCampaignStatuses();
    });
    form?.addEventListener("change", (event) => {
      if (event.target.matches("[data-page-target]")) {
        const custom = admin.querySelector("[data-custom-paths]");
        if (custom) custom.hidden = event.target.value !== "custom";
      }
      renderPreview();
      updateCampaignStatuses();
    });
    master?.addEventListener("change", updateMasterState);

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
        const input = field("promotion[logo_url]");
        if (attachment?.url && input) {
          input.value = attachment.url;
          input.dispatchEvent(new Event("input", { bubbles: true }));
        }
      });
      frame.open();
    });

    admin
      .querySelector("[data-copy-shortcode]")
      ?.addEventListener("click", async (event) => {
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

    setDevice(selectedDevice);
    updateMasterState();
    selectCampaign(selectedCampaign);
  };

  initializePromotionAdmin();
  document.addEventListener("kidia:cms-page-ready", initializePromotionAdmin);
})();
