# Kids theme appearance

`kids-appearance-20261027.json` is the reviewed, merchant-neutral Kids preset.
It includes the compact header/footer, category presentation, unified product
cards with a 0.5 outline, disabled reviews, and the 45.59px product action button (3% below 47px).
Product recommendations use the catalog card appearance, including wishlist
and outline. Product footer spacing matches category navigation; the collapsed
home search uses a 51px header to align with the fixed cart action.
Merchant identity and live catalog data are supplied by the existing Setup flow.

Kids enables `align_compact_cart` in Home, Categories and Wishlist. The three
compact headers share a 51px height, 38px content slot and 48px cart touch target;
Wishlist centers its localized title across the full header width; its cart
keeps the same position as the other two pages. Cart artwork is 26.6px,
offset 1px right and 1px up from the shared center. Expanded Home keeps the
cart fixed while its logo/search transition. Other presets retain their layout.
This renderer and order thumbnails require a new app build; publishing settings
alone cannot add support to an older installed binary. Connector 1.46.111 adds
optional order item image URLs for WooCommerce, preserving older responses.

To update a package, load the **currently active** theme snapshot and replace
only its `kids_baby` entry with this file. Preserve every other theme. Do not
reuse a complete old package or a compiled mobile design as editable form state.

`capture-kids-design.py` captures appearance from explicitly approved saved
Builder form states. Input stays private: it never copies customer records,
credentials, merchant contact details or catalog selections into the preset.
Run `python tool/builder-assets/test_capture_kids_design.py` after changes.

`publish-kids-theme.py ROOT CANDIDATE SHA256` deploys the reviewed full package.
It validates unchanged sibling themes, versions both Setup application and
preview references, retains rollback files, and refuses activation if live
source changes during deployment. Run it on the server through the authorized
deployment workflow. A content-addressed backup means the same version should
not be published twice without inspecting the earlier result.

The public Builder was verified by finishing Setup with Kids, retaining the
existing store identity, then checking the saved product controls and publishing.
This changes remotely supported design settings; it does not build an APK.
