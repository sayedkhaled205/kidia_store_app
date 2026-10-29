"""Strict, reversible patch to the current shell; no replacement of live drafts."""
def patch_parent(source):
    changes = [
        ("let mobileFrame = null, mobileReady = false, mobileEditor = '';",
         "let mobileFrame = null, mobileReady = false, mobileEditor = '';\n  let inspectorNavigation = null;"),
        ("if (forceNavigation || mobileEditor !== currentScreen) {",
         "if (inspectorNavigation === currentScreen) {\n      mobileEditor = currentScreen;\n      if (forceNavigation) inspectorNavigation = null;\n    } else if (forceNavigation || mobileEditor !== currentScreen) {"),
        ("function open(next) {",
         "function open(next, options = {}) {\n    inspectorNavigation = options.preservePreview === true ? next : null;\n    if (!inspectorNavigation) window.dispatchEvent(new CustomEvent('mobishop:preview-editor-navigation'));"),
        ("  initCompactWorkspaceNavigation();",
         "  window.addEventListener('mobishop:preview-edit-page', event => {\n    const next = event.detail?.screen;\n    if (pages.includes(next)) open(next, {preservePreview:true});\n  });\n  initCompactWorkspaceNavigation();"),
    ]
    for old,new in changes:
        assert source.count(old)==1, 'Shell contract changed: '+old
        source=source.replace(old,new)
    return source
