"""Apply the public login prefetch without replacing the live central builder."""
def patch(source):
    old = "response = await KidiaPreviewAuth.load(await load('home-builder'), window.fetch.bind(window));"
    assert source.count(old) == 1, 'Unexpected auth bridge version'
    source = source.replace(old, "response = await KidiaPreviewAuth.load(previewAuthPayload || await load('home-builder'), window.fetch.bind(window));")
    old = """  async function load(screenName) {
    return json(origin + '/account/builder/state?store=' + encodeURIComponent(store) + '&screen=' + encodeURIComponent(screenName) + '&settings_only=1&_fresh=' + Date.now());
  }"""
    new = """  let previewAuthPayload = null;
  async function load(screenName) {
    const payload = await json(origin + '/account/builder/state?store=' + encodeURIComponent(store) + '&screen=' + encodeURIComponent(screenName) + '&settings_only=1&_fresh=' + Date.now());
    if (payload.platform === 'woocommerce' && payload.store_data) {
      previewAuthPayload = {platform: payload.platform, store_data: payload.store_data};
      // Start only the public method flags while the editor is opening.
      KidiaPreviewAuth.load(previewAuthPayload, window.fetch.bind(window)).catch(() => {});
    }
    return payload;
  }"""
    assert source.count(old) == 1, 'Unexpected builder state loader'
    return source.replace(old, new)
