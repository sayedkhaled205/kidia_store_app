(() => {
  "use strict";

  const config = window.KidiaWebsiteAnalytics || {};
  if (!config.endpoint) {
    return;
  }

  const cookieName = "kidia_website_client";
  const cookieValue = document.cookie
    .split("; ")
    .find((row) => row.startsWith(`${cookieName}=`))
    ?.split("=")
    .slice(1)
    .join("=");
  const storedClient = window.localStorage?.getItem(cookieName) || "";
  const randomId =
    window.crypto?.randomUUID?.() ||
    `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
  const clientId = decodeURIComponent(cookieValue || storedClient || `web-${randomId}`);
  const sessionKey = "kidia_website_session";
  const sessionId =
    window.sessionStorage?.getItem(sessionKey) ||
    `session-${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;

  try {
    window.localStorage?.setItem(cookieName, clientId);
    window.sessionStorage?.setItem(sessionKey, sessionId);
    document.cookie = `${cookieName}=${encodeURIComponent(clientId)};path=/;max-age=31536000;SameSite=Lax`;
  } catch (_error) {
    // Tracking remains functional when browser storage is unavailable.
  }

  const send = (event, details = {}) => {
    const payload = JSON.stringify({
      event,
      client_id: clientId,
      session_id: sessionId,
      currency: config.context?.currency || "",
      object_id: Number(details.objectId || 0),
      label: String(details.label || ""),
      value: Number(details.value || 0),
      properties: details.properties || {},
    });

    if (navigator.sendBeacon) {
      navigator.sendBeacon(
        config.endpoint,
        new Blob([payload], { type: "application/json" }),
      );
      return;
    }
    fetch(config.endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: payload,
      credentials: "same-origin",
      keepalive: true,
    }).catch(() => {});
  };

  send("site_visit", {
    properties: {
      path: window.location.pathname.slice(0, 180),
      referrer: document.referrer.slice(0, 180),
    },
  });

  const context = config.context || {};
  if (context.event) {
    send(context.event, {
      objectId: context.objectId,
      label: context.label,
    });
  }
  if (context.isCheckout) {
    send("begin_checkout");
  }

  document.addEventListener("click", (event) => {
    const addButton = event.target.closest(
      ".add_to_cart_button,[name=add-to-cart],[data-product_id]",
    );
    if (addButton) {
      send("add_to_cart", {
        objectId:
          addButton.dataset.product_id ||
          addButton.value ||
          context.objectId ||
          0,
        label: addButton.getAttribute("aria-label") || "",
      });
      return;
    }

    const removeButton = event.target.closest(
      ".remove_from_cart_button,.woocommerce-cart-form .remove",
    );
    if (removeButton) {
      send("remove_from_cart", {
        objectId: removeButton.dataset.product_id || 0,
      });
    }
  });
})();
