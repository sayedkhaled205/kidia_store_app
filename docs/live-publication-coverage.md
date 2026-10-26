# Shared publication coverage

Publication is a validated data release consumed by existing renderers. It does
not download executable code. Every platform uses the same release envelope,
store/origin binding, digest checks, cache, foreground refresh and rollback.

| Setting family | Installed app behavior |
| --- | --- |
| Theme, page colors, fonts supported by the app, spacing, borders, radii | Published saved configuration |
| In-app name/logo and splash presentation | Published; splash appears on the next normal launch, not during a design refresh |
| Home sections, order, enable switches, images, text, supported action targets | Published supported block configuration |
| Category designs and subcategory behavior, category title highlight | Published; category contents remain from the store |
| Catalog, product/reviews, size chart, wishlist, account | Published page elements, settings and header/footer configuration supported by their renderers |
| Auth/cart/logout presentation | 32 existing shared controls; auth protocol and permissions remain native/API-driven |
| Support contacts | Four new shared controls: public WhatsApp/email and independent enable switches |
| Native checkout presentation | Three saved styles on WooCommerce/Odoo, now part of the shared release |
| Shopify checkout | Official Shopify checkout presentation remains controlled by Shopify |
| Products/prices, addresses, shipping/rates, payment availability | Live connector APIs; never stale public design copies |
| Customer language | Primary phone locale (Arabic or English fallback), persistent customer override; publication must not reset it |
| Launcher name/icon, bundle ID, signing, permissions, native SDK, new renderers | Requires a native binary update |

New consumers introduced in this change require **one baseline Android/iOS app
update**. After that, edits within these supported contracts use Publish without
another app version. Apps already installed before these consumers existed
cannot gain them from publication alone. No 100% coverage claim is made.

Updates are checked on foreground/resume and at the existing 30-second interval.
Activation waits for the safe Home route: it does not replace a payment or login
form while the customer is using it. Cached approved design remains available
offline. Saving a draft and publishing it remain separate operations.

Unsupported brand/bundle blocks retain the publisher's existing rejection until
their real platform-specific catalog contracts exist. A new gateway integration
or platform feature cannot be manufactured by changing a presentation setting.
Odoo card-payment availability is not established by these presentation tests.

Regression coverage includes repeated publications and rollback on all three
platforms, startup continuity, mounted contact updates/removal, Odoo account/auth
widgets and retained login input, strict shared contact validation, checkout
allowlisting, owner/concurrency checks and transaction-only backend publication.
CI also checks that generated server/mobile schema copies match and rebuilds the
preview from committed Flutter source to prevent stale preview deployments.
