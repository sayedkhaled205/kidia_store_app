(function (scope) {
  'use strict';
  const allowedMethods = ['password', 'email_password', 'phone_password', 'phone_otp', 'google', 'registration'];
  async function load(payload, fetchPublic) {
    if (payload.platform !== 'woocommerce') throw new Error('Unsupported preview authentication platform.');
    const store = payload.store_data || {};
    const url = new URL(store.url || store.home_url || store.website_url || store.base_url || '');
    if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash)
      throw new Error('Invalid preview store origin.');
    url.pathname = url.pathname.replace(/\/+$/, '') + '/wp-json/mobishop/v1/auth/native/config';
    url.search = '?platform=android';
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000);
    try {
      const response = await fetchPublic(url.href, {
        credentials: 'omit', redirect: 'error', referrerPolicy: 'no-referrer',
        headers: {Accept: 'application/json'}, signal: controller.signal
      });
      if (response.status === 404) return {
        version: 1, enabled: true, methods: {email_password: true, registration: true}
      };
      if (!response.ok) throw new Error('Preview authentication settings unavailable.');
      const config = await response.json();
      if (config.version !== 1 || typeof config.enabled !== 'boolean' ||
          !config.methods || typeof config.methods !== 'object' || Array.isArray(config.methods))
        throw new Error('Invalid preview authentication configuration.');
      return {version: 1, enabled: config.enabled, methods: Object.fromEntries(
        allowedMethods.map(key => [key, config.methods[key] === true])
      )};
    } finally { clearTimeout(timeout); }
  }
  const api = {load};
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else scope.KidiaPreviewAuth = api;
})(typeof window !== 'undefined' ? window : globalThis);
