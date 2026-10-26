"""Apply only reviewed preview contract fixes to the current live shell."""
from pathlib import Path

def replace_once(source, before, after):
    assert source.count(before) == 1, 'Unexpected live source: ' + before[:65]
    return source.replace(before, after, 1)

def repair_central(source):
    source = repair_centered_loader_central(source)
    source = repair_category_brand_central(source)
    if '/* preview-commerce-contract-v1 */' in source:
        return source
    helper = Path(__file__).with_name('preview-commerce-config.js').read_text()
    source = replace_once(source, '  function sendMobilePreview() {',
        '  function sendMobilePreview(forceNavigation = false) {')
    source = replace_once(source, '    if (mobileEditor !== currentScreen) {',
        '    if (forceNavigation || mobileEditor !== currentScreen) {')
    source = replace_once(source, "    if (message.type !== 'mobishop-preview-catalog-request') return;", """    if (message.type === 'mobishop-preview-checkout-config-request') {
      const requestId = Number(message.request_id);
      if (!Number.isSafeInteger(requestId) || requestId < 1 || !store) return;
      let response;
      try {
        response = await KidiaPreviewCommerce.load(await load('checkout-builder'), window.fetch.bind(window));
      } catch (error) { response = {error: 'Checkout preview configuration unavailable.'}; }
      mobileFrame.contentWindow.postMessage(JSON.stringify(Object.assign(response, {
        type: 'mobishop-preview-checkout-config-response', request_id: requestId
      })), location.origin);
      return;
    }
    if (message.type !== 'mobishop-preview-catalog-request') return;""")
    source = replace_once(source, "    positionMobile();\n    sendMobilePreview();\n    setTransition('');",
        "    positionMobile();\n    sendMobilePreview(true);\n    setTransition('');")
    source = replace_once(source, "      frame.inert = false;\n      setTransition('');\n      return;",
        "      frame.inert = false;\n      sendMobilePreview(true);\n      setTransition('');\n      return;")
    return '/* preview-commerce-contract-v1 */\n' + helper + '\n' + source

def repair_centered_loader_central(source):
    if '/* centered-page-loader-v1 */' in source:
        return source
    return replace_once(source,
        "  const transitionText = document.getElementById('kidia-page-transition-text');",
        """  const transitionText = document.getElementById('kidia-page-transition-text');
  /* centered-page-loader-v1 */
  const loaderStyle = document.createElement('style');
  loaderStyle.textContent = `
    #kidia-page-transition:not(.is-error) {
      inset: 0; transform: none; width: auto; max-width: none;
      display: grid; place-items: center; padding: 0; border: 0;
      border-radius: 0; background: transparent; box-shadow: none;
      pointer-events: none;
    }
    #kidia-page-transition:not(.is-error)::before {
      content: ''; width: 48px; height: 48px; box-sizing: border-box;
      border: 4px solid #dfeee9; border-top-color: var(--web-accent, #21806b);
      border-radius: 50%; animation: kidia-page-loader-spin .8s linear infinite;
    }
    #kidia-page-transition:not(.is-error) #kidia-page-transition-text {
      position: absolute; width: 1px; height: 1px; padding: 0;
      margin: -1px; overflow: hidden; clip-path: inset(50%); white-space: nowrap;
    }
    @keyframes kidia-page-loader-spin { to { transform: rotate(360deg); } }
    @media (prefers-reduced-motion: reduce) {
      #kidia-page-transition:not(.is-error)::before { animation-duration: 2s; }
    }
  `;
  document.head.append(loaderStyle);""")

def repair_category_brand_central(source):
    if 'identity: applicationPreviewIdentity || {},' in source:
        return source
    return replace_once(source, '          settings: payload.state || {},',
        '          settings: payload.state || {},\n          identity: applicationPreviewIdentity || {},')

def repair_frame(source):
    if '/* category-designer-v5:' in source:
        return repair_product_outline_frame(source)
    if any(f'/* category-designer-v{v}:' in source for v in (1, 2, 3, 4)):
        end = source.index("})(typeof window==='undefined'?globalThis:window);") + len("})(typeof window==='undefined'?globalThis:window);")
        source = source[end:].lstrip('\n')
        source = source.replace("\n      if (screen === 'category-builder') KidiaCategoryDesigner.prepare(root);", '')
        source = source.replace("\n    if (screen === 'category-builder') { KidiaCategoryDesigner.hydrate(root, store); if (window.KidiaCategoryMenu) window.KidiaCategoryMenu.init(); }", '')
        source = source.replace("\n    if (screen === 'category-builder') { KidiaCategoryDesigner.hydrate(root, store, payload.settings); if (window.KidiaCategoryMenu) window.KidiaCategoryMenu.init(); }", '')
    helper = Path(__file__).with_name('category-designer.js').read_text(encoding='utf-8')
    source = replace_once(source,
        '      root.innerHTML = normalizeReferenceHtml(html);',
        "      root.innerHTML = normalizeReferenceHtml(html);\n      if (screen === 'category-builder') KidiaCategoryDesigner.prepare(root);")
    source = replace_once(source,
        '  async function hydrate(payload) {\n    const store = payload && payload.store ? payload.store : {};',
        "  async function hydrate(payload) {\n    const store = payload && payload.store ? payload.store : {};\n    if (screen === 'category-builder') { KidiaCategoryDesigner.hydrate(root, store, payload.settings, payload.identity); if (window.KidiaCategoryMenu) window.KidiaCategoryMenu.init(); }")
    return repair_product_outline_frame(helper + '\n' + source)

def repair_product_outline_frame(source):
    if '/* product-outline-field-v2 */' in source:
        return source
    helper = Path(__file__).with_name('product-outline.js').read_text(encoding='utf-8')
    if '/* product-outline-field-v1 */' in source:
        start = source.index('/* product-outline-field-v1 */')
        closing = "})(typeof window === 'undefined' ? globalThis : window);"
        end = source.index(closing, start) + len(closing)
        return source[:start] + '/* product-outline-field-v2 */\n' + helper + source[end:]
    source = replace_once(source, '      root.innerHTML = normalizeReferenceHtml(html);',
        '      root.innerHTML = normalizeReferenceHtml(html);\n      KidiaProductOutline.prepare(root);')
    source = replace_once(source, '    const store = payload && payload.store ? payload.store : {};\n    if (screen === \'category-builder\')',
        '    const store = payload && payload.store ? payload.store : {};\n    KidiaProductOutline.prepare(root, payload.identity);\n    if (screen === \'category-builder\')')
    source = replace_once(source, '        KidiaApplicationSave.prepareHomeItems(rendered, savedBlock.settings || {})();',
        '        KidiaProductOutline.prepare(rendered, payload.identity);\n        KidiaApplicationSave.prepareHomeItems(rendered, savedBlock.settings || {})();')
    return '/* product-outline-field-v2 */\n' + helper + '\n' + source
