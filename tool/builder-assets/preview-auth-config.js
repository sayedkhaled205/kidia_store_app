(function (scope) {
  'use strict';
  const allowedMethods = ['password', 'email_password', 'phone_password', 'phone_otp', 'google', 'facebook', 'registration'];
  const capabilities = new Map();
  async function load(payload, fetchPublic, {fresh = false} = {}) {
    if (payload.platform !== 'woocommerce') throw new Error('Unsupported preview authentication platform.');
    const store = payload.store_data || {};
    const url = new URL(store.url || store.home_url || store.website_url || store.base_url || '');
    if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash)
      throw new Error('Invalid preview store origin.');
    url.pathname = url.pathname.replace(/\/+$/, '') + '/wp-json/mobishop/v1/auth/native/config';
    url.search = '?platform=android';
    const key = url.href;
    const cached = capabilities.get(key);
    if (!fresh && cached && (cached.pending || cached.expires > Date.now())) return cached.promise;
    const entry = {pending: true, expires: 0, promise: null};
    entry.promise = request(url, fetchPublic).then(value => {
      entry.pending = false;
      entry.expires = Date.now() + 30000;
      return value;
    }, error => {
      if (capabilities.get(key) === entry) capabilities.delete(key);
      throw error;
    });
    if (capabilities.size >= 16) capabilities.delete(capabilities.keys().next().value);
    capabilities.set(key, entry);
    return entry.promise;
  }
  async function request(url, fetchPublic) {
    // Availability can change after native Google registration. Do not reuse a
    // browser/CDN response from before that registration on a later preview.
    url.searchParams.set('_preview', Date.now().toString(36));
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000);
    try {
      const response = await fetchPublic(url.href, {
        credentials: 'omit', redirect: 'error', referrerPolicy: 'no-referrer', cache: 'no-store',
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
      return {version: 1, enabled: config.enabled,
        phone_country_code: /^[1-9]\d{0,3}$/.test(String(config.phone_country_code || '')) ? String(config.phone_country_code) : '',
        methods: Object.fromEntries(
        allowedMethods.map(key => [key, config.methods[key] === true])
      )};
    } finally { clearTimeout(timeout); }
  }
  const api = {load};
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else scope.KidiaPreviewAuth = api;
})(typeof window !== 'undefined' ? window : globalThis);
