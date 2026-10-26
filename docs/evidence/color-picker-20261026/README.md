# Builder color picker dismissal — 2026-10-26

The category appearance fields wrap native color inputs in full-grid-width labels. Chromium forwards a click on the label's empty area to the color input, reopening the picker just dismissed by that same click.

The shared guard cancels only color-label activation outside the actual control, and blurs a color input on an outside pointer press. Native swatch clicks, keyboard activation, and input/change events remain intact. Delegated handlers cover dynamically added fields and same-origin editor frames. The WordPress builder enqueues the same source asset.

Validation:

- Three regression tests passed: label forwarding before/after the fix; direct swatch clicks and unchanged form events; dynamically loaded/cached editor frames and fields.
- PHP syntax and Git whitespace checks passed.
- Deployment staging, refusal to overwrite a concurrent index edit, and activation were verified in a temporary directory.
- In-app browser: old label whitespace reopened the native picker (accessibility tree exposed its two-dimensional color slider). The fixed review page opened the picker from the swatch, accepted a keyboard color adjustment (`#e8f7fc` → `#e8f8fd`), and dismissed it on the first outside click. The original draft value was restored; no theme or store setting was saved.
- After activation, the main builder URL was reloaded: swatch click opened the native picker; one click in the label whitespace closed it. Screenshot: `live-color-dismissed.png`.

Deployment adds only one immutable helper script reference to the latest live index, preserving the current `23462e092d03` preview and all other builder assets.

- Source commit: `d3c7b84cc493824c7b1f93545a706125394f4119`
- Live helper: `assets/color-picker-0f26bdd05c15.js`
- SHA256: `0f26bdd05c15c703e8fbe82c8433da698329b6174222cb062e1236f054a40f42`
- Backup: `/home/woomobile/woomobile-api/public/color-picker-backup-0f26bdd05c15`
- Public HTTP verification confirmed the main index references the helper and the served helper matches the tested source byte-for-byte.

This is a builder interface fix; it does not require an APK build or alter stored theme colors.
