Kids retains separate root and subcategory browsing. Opening a subcategory now
opens its product list, with its children in a compact horizontal row above the
existing filters. Three cards fit when there are at most three, otherwise four;
longer lists scroll. Cards inherit the saved category artwork, outline, colors
and name highlight. Selecting a child opens its scoped products; leaves omit the
row. Product filters and cards retain their existing implementation.

The quick-add sheet changes only its footer: a wishlist action beside a large
pill-shaped add button, using the product footer colors and button height. The
existing wishlist access rules, saved state, variant selection and add callback
are retained. Its gallery, product title, price and options remain unchanged.

`category_general.navigation_mode=products_with_children` and product footer
`quick_add_layout=wishlist_button` are enabled in the shared Kids preset and
editable in the ordinary Builder forms. Other themes keep their existing
defaults. Connector 1.46.114 preserves both choices.

This adds native renderer behavior and requires one new application build.
Once that renderer is installed, these saved choices use Publish now. No native
release was dispatched as part of this change.

Validation covers RTL/LTR, narrow screens and larger text, category routing,
three/four/long rows, wishlist mutation, localized cart actions, Android bottom
insets, form persistence and connector save/read contracts. Deployment uses
staged files, live dependency checks and rollback copies.
