# Amazon-style application parity checklist

This checklist is the implementation contract for the `amazon_marketplace` preset. It recreates Amazon Shopping's information architecture and interaction density while retaining the merchant's own name, logo, colors, catalog, policies and WooCommerce data.

## Global chrome

- [x] Store branding instead of Amazon branding
- [x] Persistent rounded search field
- [x] Voice-search affordance
- [x] Menu, account, orders and cart shortcuts
- [x] Cart count badge
- [x] Delivery/address strip linked to saved addresses
- [x] Compact inner-page headers
- [x] Four-item bottom navigation
- [x] RTL/LTR and merchant colors
- [ ] Optional camera/barcode search action
- [ ] Dedicated draggable Location header item for every page

## Home

- [x] Delivery strip
- [x] Department shortcuts
- [x] Hero campaign carousel
- [x] Category carousel/grid
- [x] Today's Deals countdown
- [x] Deal product carousel
- [x] Promotional tile grid
- [x] Recommended product grid
- [x] Brand carousel
- [x] Product rating, badge, wishlist and quick-add controls

## Categories

- [x] Separate department navigation
- [x] Three-column compact grid
- [x] Circular category artwork
- [x] Subcategory navigation inherited from the Category Builder

## Search and catalog

- [x] Sticky sort/filter row and result count
- [x] Two-column dense product grid
- [x] Swipeable product images
- [x] Name, price, rating and deal badge
- [x] Wishlist and quick add
- [x] Automatic pagination
- [ ] Sponsored-result label (requires advertising data source)

## Product detail

- [x] Image gallery, counter and zoom
- [x] Title, price, rating and deal badge
- [x] Variation chips
- [x] Sticky information tabs
- [x] Accordion description and reviews
- [x] Related/recommended products
- [x] Persistent purchase action
- [ ] Separate Buy Now action
- [ ] Delivery promise/location block
- [ ] Seller/fulfilment block
- [ ] Frequently Bought Together block

## Cart and checkout

- [x] WooCommerce cart data and checkout remain authoritative
- [x] Quantity and removal actions use the existing real cart flow
- [x] Merchant checkout design is preserved
- [ ] Save for later section
- [ ] Gift receipt control

## Wishlist

- [x] Sign-in state
- [x] Empty state
- [x] Saved products grid
- [x] Recommendations in every state

## Account, orders and addresses

- [x] Account summary
- [x] Orders shortcut
- [x] Saved addresses
- [x] Profile and support
- [x] Logout
- [ ] Buy Again shelf
- [ ] Order tracking timeline

## Required states and QA

- [x] Signed-out wishlist state
- [x] Empty wishlist state
- [x] Product-filled wishlist state
- [ ] Empty catalog/search state visual parity
- [ ] Loading/skeleton visual parity
- [ ] Network/error visual parity
- [ ] Device QA at narrow Android, standard Android and iPhone widths
