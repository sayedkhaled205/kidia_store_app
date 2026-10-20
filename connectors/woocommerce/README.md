# WooCommerce connector release source

This is the canonical source of **Mobi2App Connector for WooCommerce** distributed
to new WooMobile stores. The `mobishop/` directory and `mobishop.zip` are the older
CMS plugin; do not use those packages as replacements for this connector.

Build and verify:

```sh
python3 tool/build_woocommerce_connector.py
python3 -m unittest discover -s tool -p test_build_woocommerce_connector.py
unzip -q build/woocommerce/mobi2app-connector-1.46.75.zip -d build/woocommerce
MOBISHOP_CONNECTOR_TEST_ROOT="$PWD/build/woocommerce/mobi2app-connector" \
  php connectors/woocommerce/tests/website-auth-contract-test.php
```

The output is a versioned installable ZIP and `connector-release.json` containing
its SHA256. CI runs the PHP contract against the **packaged** code, covering the
existing customer-session issuer and the restored website authentication bridge.

`source-manifest.json` pins every file in the reviewed release. Connector-specific
files live in `source/`; unchanged assets are read from their pinned paths in
`mobishop/` to avoid duplicating the entire legacy plugin. Source hashes normalize
ordinary text line endings for Windows/Linux, then reconstruct the original
release bytes. Mixed-line-ending files are kept byte-for-byte in `source/`.
Unlisted files never enter the ZIP. An unrelated edit to a shared source fails
packaging until its inclusion is explicitly reviewed.

For a connector change, edit its dedicated source, update the corresponding
`source_sha256` and final-byte `sha256` in the manifest, and bump the version in the
manifest, plugin header/constant, and readme together. If a shared file needs a
connector-specific change, copy it into `source/` and change that manifest entry's
`source` first. Do not edit the legacy plugin merely to change the connector.

The initial manifest preserves all 492 files from the verified 1.46.75 release.
It includes automatic central setup, store data, application state and push
bridges, plus website authentication. Packaging fails if one of these modules or
its registration disappears. Website authentication inherits the store's actual
login methods; it does not invent OTP or social providers for an unconfigured site.

Use a GitHub release tag `connector-vX.Y.Z` to attach this tested ZIP. The legacy
WordPress.org deployment workflow skips these tags. Directory approval and a
WooMobile distribution deployment remain distinct operations; this workflow does
not bypass either authorization.
