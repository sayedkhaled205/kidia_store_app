# Combined Builder release integration

The authenticated Builder request selects both platforms only when the current store, owner, license, Firebase configuration and registered signing identities match. APNs delivery readiness remains independent and is never inferred from an Apple distribution profile.

`backend/` contains the corresponding deployed Laravel service/controller changes. Kidia uses its existing Codemagic-managed Apple signing profile and an encrypted server-side Android upload key. Existing customer secret-group workflows remain unchanged. The managed workflow checks the production store and both existing application identifiers before building. No private key or password belongs in this repository.

The one-time operator `provision.php` writes the upload identity only when no registered release signer exists; subsequent executions verify and reuse the encrypted key. It never rotates an existing identity. It exports only the public certificate separately. The registration starts new builds at 302, after the independently uploaded Apple build 301. Normal version allocation considers every previous store build, including failed builds, under the existing store/activation locks.

`stage.php` verifies original/current checksums and PHP syntax before creating a private staged copy. `verify_backend.php` loads those staged classes and the actual store configuration, makes no database writes, and replaces Codemagic HTTP requests with an assertion fake. It checks isolation, expired/unregistered signing, SDK binding, credentials, routing, saved design and platform reporting. `deploy.php` requires the expected source hashes and saves original files in private storage before replacement. Refresh the Laravel configuration cache as the application owner after deployment.

The workflow produces signed APK, AAB and IPA files plus `mobishop-build-files.zip`, verifies the exported signatures, and reports the actual combined request ID through the existing callback. Building does not submit either storefront for public review. Store publication remains a separate customer action.
