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
  const queueKey = "kidia_website_analytics_queue_v1";
  let flushing = false;
  let memoryQueue = [];

  try {
    window.localStorage?.setItem(cookieName, clientId);
    window.sessionStorage?.setItem(sessionKey, sessionId);
    document.cookie = `${cookieName}=${encodeURIComponent(clientId)};path=/;max-age=31536000;SameSite=Lax`;
  } catch (_error) {
    // Tracking remains functional when browser storage is unavailable.
  }

  const readQueue = () => {
    try {
      const value = JSON.parse(window.localStorage?.getItem(queueKey) || "[]");
      memoryQueue = Array.isArray(value) ? value.slice(-200) : memoryQueue;
    } catch (_error) {
      // Fall back to the in-memory copy for privacy-restricted browsers.
    }
    return memoryQueue.slice();
  };
  const writeQueue = (queue) => {
    memoryQueue = queue.slice(-200);
    try {
      window.localStorage?.setItem(queueKey, JSON.stringify(memoryQueue));
    } catch (_error) {
      // The current request still runs when persistent storage is unavailable.
    }
  };
  const eventId = () =>
    window.crypto?.randomUUID?.() ||
    `event-${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
  const flush = async () => {
    if (flushing || !window.navigator.onLine) {
      return;
    }
    flushing = true;
    try {
      let queue = readQueue();
      while (queue.length) {
        const current = queue[0];
        const response = await fetch(config.endpoint, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(current),
          credentials: "same-origin",
          keepalive: true,
          cache: "no-store",
        });
        if (!response.ok) {
          break;
        }
        queue = readQueue();
        const recordedIndex = queue.findIndex(
          (item) => item.event_id === current.event_id,
        );
        if (recordedIndex >= 0) {
          queue.splice(recordedIndex, 1);
        }
        writeQueue(queue);
      }
    } catch (_error) {
      // Keep the unsent events for the next page load or online signal.
    } finally {
      flushing = false;
    }
  };
  const send = (event, details = {}) => {
    const payload = {
      event_id: eventId(),
      event,
      client_id: clientId,
      session_id: sessionId,
      currency: config.context?.currency || "",
      object_id: Number(details.objectId || 0),
      label: String(details.label || ""),
      value: Number(details.value || 0),
      properties: details.properties || {},
    };
    const queue = readQueue();
    queue.push(payload);
    writeQueue(queue);
    void flush();
  };

  window.addEventListener("online", () => {
    void flush();
  });
  void flush();

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

  /*
   * Add/remove intent is recorded by the successful WooCommerce cart hooks.
   * Counting the initial click here as well used a different label and escaped
   * server deduplication, so one real cart change appeared twice in Analytics.
   */
})();
