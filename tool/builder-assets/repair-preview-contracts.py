"""Apply only reviewed preview contract fixes to the current live shell."""
from pathlib import Path

def replace_once(source, before, after):
    assert source.count(before) == 1, 'Unexpected live source: ' + before[:65]
    return source.replace(before, after, 1)

def repair_central(source):
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

def repair_frame(source):
    if '/* category-designer-v3:' in source:
        return source
    if '/* category-designer-v1:' in source or '/* category-designer-v2:' in source:
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
        "  async function hydrate(payload) {\n    const store = payload && payload.store ? payload.store : {};\n    if (screen === 'category-builder') { KidiaCategoryDesigner.hydrate(root, store, payload.settings); if (window.KidiaCategoryMenu) window.KidiaCategoryMenu.init(); }")
    return helper + '\n' + source
