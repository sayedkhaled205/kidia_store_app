(() => {
  "use strict";

  let initialized = false;
  let bootAttempts = 0;

  const readConfig = () => {
    if (window.KidiaAppPromotion?.settings) {
      return window.KidiaAppPromotion;
    }
    const embedded = document.querySelector("[data-kidia-app-promo-config]");
    if (!embedded?.textContent) return null;
    try {
      return JSON.parse(embedded.textContent);
    } catch (_error) {
      return null;
    }
  };

  const initializePromotion = () => {
  if (initialized) return true;
  const config = readConfig();
  if (!config) return false;
  const settings = config.settings || {};
  if (!settings.enabled) return true;
  initialized = true;
  let root = document.querySelector("[data-kidia-app-promo-root]");
  if (!root) {
    root = document.createElement("div");
    root.className = "kidia-app-promo-root";
    root.dataset.kidiaAppPromoRoot = "";
    (document.body || document.documentElement).append(root);
  }

  const ua = navigator.userAgent || "";
  const isIOS = /iPad|iPhone|iPod/i.test(ua);
  const isAndroid = /Android/i.test(ua);
  const isHuawei = /HUAWEI|HONOR/i.test(ua);
  const isMobile = window.matchMedia("(max-width: 767px)").matches;
  const pagePath = window.location.pathname || config.page?.path || "/";
  const storagePrefix = "kidia_app_promo_dismissed_v1_";
  const sessionPrefix = "kidia_app_promo_session_v1_";
  let interruptionVisible = false;

  const listPaths = (value) =>
    String(value || "")
      .split(/[\n,]+/)
      .map((path) => path.trim())
      .filter(Boolean);
  const matchesPath = (paths) =>
    paths.some((path) => pagePath.startsWith(path.startsWith("/") ? path : `/${path}`));
  const deviceAllowed = () => {
    switch (settings.audience_devices) {
      case "mobile":
        return isMobile;
      case "desktop":
        return !isMobile;
      case "android":
        return isAndroid;
      case "ios":
        return isIOS;
      default:
        return true;
    }
  };
  const visitorAllowed = () => {
    if (settings.audience_users === "guests") return !config.loggedIn;
    if (settings.audience_users === "customers") return Boolean(config.loggedIn);
    return true;
  };
  const pageAllowed = () => {
    if (matchesPath(listPaths(settings.excluded_paths))) return false;
    if (settings.page_target === "custom") {
      return matchesPath(listPaths(settings.custom_paths));
    }
    return (
      settings.page_target === "all" ||
      settings.page_target === config.page?.type
    );
  };
  if (!deviceAllowed() || !visitorAllowed() || !pageAllowed()) return;

  const storeUrl = () => {
    if (settings.smart_url) return settings.smart_url;
    if (isHuawei && settings.huawei_url) return settings.huawei_url;
    if (isIOS && settings.ios_url) return settings.ios_url;
    if (isAndroid && settings.android_url) return settings.android_url;
    return (
      settings.android_url ||
      settings.ios_url ||
      settings.huawei_url ||
      settings.qr_url ||
      ""
    );
  };
  const destination = storeUrl();
  const campaignDestination = (campaign) => {
    if (campaign === "desktop_qr" && settings.qr_url) {
      return settings.qr_url;
    }
    return destination || settings.deep_link || "";
  };

  const lifetime = {
    daily: 86400000,
    three_days: 259200000,
    weekly: 604800000,
  };
  const canShow = (campaign) => {
    if (settings.frequency === "always") return true;
    try {
      if (settings.frequency === "session") {
        return !window.sessionStorage.getItem(`${sessionPrefix}${campaign}`);
      }
      const dismissedAt = Number(
        window.localStorage.getItem(`${storagePrefix}${campaign}`) || 0,
      );
      return !dismissedAt || Date.now() - dismissedAt >= (lifetime[settings.frequency] || lifetime.daily);
    } catch (_error) {
      return true;
    }
  };
  const rememberDismissal = (campaign) => {
    try {
      if (settings.frequency === "session") {
        window.sessionStorage.setItem(`${sessionPrefix}${campaign}`, "1");
      } else if (settings.frequency !== "always") {
        window.localStorage.setItem(`${storagePrefix}${campaign}`, String(Date.now()));
      }
    } catch (_error) {
      // Privacy-restricted browsers can still dismiss the current element.
    }
  };
  const track = (event, campaign) => {
    if (!config.ajaxUrl || !config.nonce) return;
    const data = new URLSearchParams({
      action: "kidia_mobile_app_promotion_event",
      nonce: config.nonce,
      event,
      campaign,
    });
    if (navigator.sendBeacon) {
      navigator.sendBeacon(config.ajaxUrl, data);
      return;
    }
    fetch(config.ajaxUrl, {
      method: "POST",
      credentials: "same-origin",
      headers: { "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8" },
      body: data.toString(),
      keepalive: true,
    }).catch(() => {});
  };
  const create = (tag, className, text) => {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  };
  const applyTheme = (node) => {
    node.style.setProperty("--kidia-app-promo-brand", settings.primary_color || "#2f806e");
    node.style.setProperty("--kidia-app-promo-ink", settings.text_color || "#15352d");
    node.style.setProperty("--kidia-app-promo-surface", settings.surface_color || "#fff");
  };
  const icon = () => {
    const holder = create("span", "kidia-app-promo__icon");
    if (settings.logo_url) {
      const image = create("img");
      image.src = settings.logo_url;
      image.alt = "";
      image.loading = "lazy";
      holder.append(image);
    } else {
      holder.textContent =
        String(settings.app_name || "A").trim().slice(0, 1).toUpperCase() || "A";
    }
    return holder;
  };
  const copy = (campaignType) => {
    const holder = create("span", "kidia-app-promo__copy");
    const headline =
      campaignType === "floating_button"
        ? settings.floating_button?.label || settings.app_name
        : settings.app_name;
    holder.append(create("strong", "", headline || "Our app"));
    if (campaignType !== "floating_button") {
      holder.append(
        create(
          "span",
          "",
          settings.tagline || settings.description || "Shop in our app",
        ),
      );
      if (settings.offer_text || settings.coupon_code) {
        const offer = create(
          "small",
          "kidia-app-promo__offer",
          settings.offer_text || "App-only offer",
        );
        if (settings.coupon_code) {
          offer.append(
            create("b", "kidia-app-promo__coupon", settings.coupon_code),
          );
        }
        holder.append(offer);
      }
    }
    return holder;
  };
  const openDestination = (event, campaign) => {
    event?.preventDefault();
    track("click", campaign);
    const fallback =
      campaign === "desktop_qr" && settings.qr_url
        ? settings.qr_url
        : destination;
    if (settings.deep_link && isMobile) {
      let pageHidden = false;
      const hidden = () => {
        pageHidden = true;
      };
      window.addEventListener("pagehide", hidden, { once: true });
      window.location.href = settings.deep_link;
      if (fallback) {
        window.setTimeout(() => {
          if (!pageHidden && document.visibilityState === "visible") {
            window.location.href = fallback;
          }
        }, 900);
      }
      return;
    }
    if (fallback) window.location.href = fallback;
  };
  const hide = (node, backdrop, campaign) => {
    node.classList.add("is-hiding");
    backdrop?.classList.add("is-hiding");
    rememberDismissal(campaign);
    track("dismiss", campaign);
    window.setTimeout(() => {
      node.remove();
      backdrop?.remove();
      if (["popup", "bottom_sheet"].includes(campaign)) {
        interruptionVisible = false;
      }
    }, 190);
  };

  const build = (displayType, campaign) => {
    const options = settings[campaign] || {};
    const target = campaignDestination(campaign);
    const node =
      displayType === "floating_button"
        ? create("button", `kidia-app-promo kidia-app-promo--${displayType}`)
        : create("section", `kidia-app-promo kidia-app-promo--${displayType}`);
    applyTheme(node);
    node.dataset.kidiaAppPromotion = campaign;
    node.setAttribute("aria-label", `${settings.app_name || "App"} download`);
    if (displayType === "floating_button") node.type = "button";
    if (options.position) node.classList.add(`is-${options.position}`);
    if (options.style) node.classList.add(`is-${options.style}`);
    node.append(icon(), copy(displayType));

    if (displayType === "desktop_qr" && target) {
      const qrHolder = create("span", "kidia-app-promo__qr");
      node.append(qrHolder);
      if (window.QRCode) {
        new window.QRCode(qrHolder, {
          text: target,
          width: 92,
          height: 92,
          colorDark: settings.text_color || "#15352d",
          colorLight: "#ffffff",
          correctLevel: window.QRCode.CorrectLevel.M,
        });
      }
    }

    if (displayType === "floating_button") {
      node.addEventListener("click", (event) => openDestination(event, campaign));
      return { node, backdrop: null };
    }

    if (target) {
      const action = create(
        "a",
        "kidia-app-promo__action",
        settings.deep_link && isMobile
          ? settings.open_label || "Open app"
          : settings.button_label || "Download app",
      );
      action.href = target;
      action.rel = "noopener";
      action.addEventListener("click", (event) => openDestination(event, campaign));
      node.append(action);
    }

    let backdrop = null;
    if (!["inline_banner"].includes(displayType)) {
      const dismiss = create("button", "kidia-app-promo__dismiss", "×");
      dismiss.type = "button";
      dismiss.setAttribute("aria-label", settings.dismiss_label || "Dismiss");
      dismiss.addEventListener("click", () => hide(node, backdrop, campaign));
      node.append(dismiss);
    }
    if (displayType === "popup") {
      node.setAttribute("role", "dialog");
      node.setAttribute("aria-modal", "true");
      backdrop = create("div", "kidia-app-promo-backdrop");
      backdrop.addEventListener("click", () => hide(node, backdrop, campaign));
    }
    return { node, backdrop };
  };

  const show = (displayType, campaign, slot = null) => {
    const requiresDestination = ["desktop_qr", "floating_button"].includes(
      displayType,
    );
    if (requiresDestination && !campaignDestination(campaign)) return;
    if (!canShow(campaign)) return;
    if (["popup", "bottom_sheet"].includes(displayType) && interruptionVisible) {
      return;
    }
    const { node, backdrop } = build(displayType, campaign);
    if (backdrop) root.append(backdrop);
    if (displayType === "smart_banner" && settings.smart_banner?.position === "top") {
      document.body.prepend(node);
    } else if (slot) {
      slot.append(node);
    } else {
      root.append(node);
    }
    if (["popup", "bottom_sheet"].includes(displayType)) {
      interruptionVisible = true;
      node.querySelector(".kidia-app-promo__dismiss")?.focus({ preventScroll: true });
    }
    track("view", campaign);
  };

  const afterDelay = (seconds, callback) => {
    window.setTimeout(callback, Math.max(0, Number(seconds || 0)) * 1000);
  };
  const afterScroll = (percent, callback) => {
    const listener = () => {
      const scrollable = Math.max(
        1,
        document.documentElement.scrollHeight - window.innerHeight,
      );
      if ((window.scrollY / scrollable) * 100 >= Number(percent || 0)) {
        window.removeEventListener("scroll", listener);
        callback();
      }
    };
    window.addEventListener("scroll", listener, { passive: true });
    listener();
  };
  const scheduleTriggered = (campaign, displayType) => {
    const options = settings[campaign] || {};
    const callback = () => show(displayType, campaign);
    if (options.trigger === "scroll") {
      afterScroll(options.scroll, callback);
    } else if (options.trigger === "exit" && !isMobile) {
      const exit = (event) => {
        if (event.clientY <= 4 && !event.relatedTarget) {
          document.removeEventListener("mouseout", exit);
          callback();
        }
      };
      document.addEventListener("mouseout", exit);
    } else {
      afterDelay(options.trigger === "immediate" ? 0 : options.delay, callback);
    }
  };

  if (settings.smart_banner?.enabled) {
    afterDelay(settings.smart_banner.delay, () =>
      show("smart_banner", "smart_banner"),
    );
  }
  if (settings.desktop_qr?.enabled && !isMobile) {
    afterDelay(settings.desktop_qr.delay, () =>
      show("desktop_qr", "desktop_qr"),
    );
  }
  if (settings.floating_button?.enabled) {
    show("floating_button", "floating_button");
  }
  if (settings.bottom_sheet?.enabled && isMobile) {
    scheduleTriggered("bottom_sheet", "bottom_sheet");
  }
  if (settings.popup?.enabled) {
    const displayType =
      isMobile && settings.popup.trigger === "exit" ? "bottom_sheet" : "popup";
    scheduleTriggered("popup", displayType);
  }
  if (settings.inline_banner?.enabled) {
    document.querySelectorAll('[data-kidia-app-promo-slot="inline"]').forEach((slot) => {
      show("inline_banner", "inline_banner", slot);
    });
  }

  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return;
    const visible = root.querySelector(
      ".kidia-app-promo--popup,.kidia-app-promo--bottom_sheet",
    );
    visible?.querySelector(".kidia-app-promo__dismiss")?.click();
  });

  root.dataset.kidiaAppPromoStatus = "ready";
  return true;
  };

  const boot = () => {
    if (initializePromotion()) return;
    bootAttempts += 1;
    if (bootAttempts < 40) window.setTimeout(boot, 250);
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot, { once: true });
  } else {
    boot();
  }
  window.addEventListener("load", boot, { once: true });
  document.addEventListener("kidia:app-promotion-config-ready", boot);
})();
