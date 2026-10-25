/* Public checkout metadata for the editor; never customer or payment secrets. */
(function (scope) {
  'use strict';
  async function load(payload, fetchPublic) {
    if (payload.platform !== 'woocommerce') throw new Error('Checkout preview connector unavailable.');
    const store = payload.store_data || {};
    const url = new URL(store.url || store.home_url || store.website_url || store.base_url || '');
    if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash)
      throw new Error('Invalid preview store origin.');
    url.pathname = url.pathname.replace(/\/+$/, '') + '/wp-json/mobishop/v1/checkout-config';
    url.searchParams.set('_preview', Date.now().toString(36));
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000);
    try {
      const response = await fetchPublic(url.href, {
        credentials: 'omit', redirect: 'error', referrerPolicy: 'no-referrer', cache: 'no-store',
        headers: {Accept: 'application/json'}, signal: controller.signal
      });
      if (!response.ok) throw new Error('Checkout configuration unavailable.');
      const value = await response.json();
      if (value.version < 8 || value.renderer !== 'native' || !Array.isArray(value.fields) || !Array.isArray(value.payment_methods))
        throw new Error('Checkout configuration unsupported.');
      return {
        version: value.version, renderer: value.renderer,
        fields: value.fields.map(field => Object.fromEntries(
          ['key','group','type','label','placeholder','required','enabled','priority','options','options_by_country','default','autocomplete']
            .filter(key => Object.hasOwn(field, key)).map(key => [key,field[key]])
        )),
        defaults: {country: value.defaults?.country || '', states: value.defaults?.states || {}},
        shipping: {allow_different_address: value.shipping?.allow_different_address === true},
        payment_methods: value.payment_methods.map(method => ({
          id: method.id, title: method.title, native_adapter: method.native_adapter
        }))
      };
    } finally { clearTimeout(timeout); }
  }
  const api = {load};
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else scope.KidiaPreviewCommerce = api;
})(typeof window !== 'undefined' ? window : globalThis);
