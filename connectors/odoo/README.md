# Shared Odoo native customer connector candidate

`source/woomobile_native_customer_api51` is the versioned copy of the tested
Odoo 18 addon. It depends on the existing `woomobile_application_builder`
installation/license verifier and the original `website_sale` workflow.
There are no merchant-domain branches or private keys in this source.

Contract 101.1 projects the merchant's inherited address form labels, required
fields and country/state choices into native Flutter controls. Contract 100.1
uses the installed delivery availability, rate and tax hooks. Unknown form
controls are rejected explicitly instead of silently replaced with defaults.
Arbitrary JavaScript/CSS customizations and custom field types are not certified.

This snapshot includes source and tests; its six changed runtime files were
deployed on the authorized staging installation, with private recovery backups.
Its 17 shared transaction tests passed with all fixtures rolled back. A separate
installed-merchant projection probe also passed. The real Flutter HTTP client
loaded the initial form, selected Egypt, loaded its state fields and read one
shipping rate, then emptied its own guest basket. It did not save an address,
select a carrier, confirm an order or pay. Evidence is in
`docs/evidence/checkout101` at the repository root.

Localized form actions are supported. Empty dependent state selectors wait
for country selection; a merchant-required state without configured choices
is explicitly rejected rather than dropped.
The paid checkout adapter is incomplete. Do not advertise universal card
compatibility, activate a payment fallback, or mark payment successful from
the legacy website handoff route. Existing access gates remain required.

Local isolated parser/contract tests (no Odoo installation needed):

```sh
python -m pip install lxml==6.1.1
python source/woomobile_native_customer_api51/tests/test_cart_contract85_host.py
python source/woomobile_native_customer_api51/tests/test_shipping100_host.py
python source/woomobile_native_customer_api51/tests/test_checkout101_host.py
```

Runtime integration tests require Odoo 18, its original installed business
modules, and a disposable/rollback test database. They must not be replaced by
the host tests or represented as a paid checkout acceptance test.
