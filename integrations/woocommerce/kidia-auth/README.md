# Kidia website authentication integration

Scoped website integration; the common identity, enrollment, ticket and locking logic remains in the WooCommerce connector. This folder is not included in the public connector ZIP.

Deployment map (preserve other plugin files and social button assets):
- website/kidia-login-page.php -> wp-content/plugins/kidia-login-page/kidia-login-page.php
- website/content-login.php -> that plugin/templates/content-login.php
- website/login.js -> that plugin/assets/js/login.js
- website/kidia-firebase-otp.php and .js -> wp-content/mu-plugins/
- website/kidia-shared-auth.php and .js -> wp-content/mu-plugins/

Requires connector 1.46.124 or its reviewed native-auth/account hotfixes. Website completion uses WordPress cookie + nonce + browser/session-bound ticket. Repeated phone input stores contact-only metadata; it is never OTP identity. Existing-account access always requires its password, signed OTP, or linked provider identity. Automatic pending social-account merging is disabled.

Checks: php website-auth-contract-test.php; php render-fixture.php (also account and account collected); node website-auth-ui-test.cjs with root jsdom dev dependency. Fixtures are synthetic. Real SMS delivery and provider consent require a separate user-operated device test.

Before deployment compare current live hashes, preserve Google/Facebook assets, back up scoped files, lint all PHP files, verify versions in public HTML and actual signup UI. Never deploy a stale whole plugin.

Contact-only billing/FME copies are excluded before bounded identity queries. Website OTP uses its own server-configured Firebase project; it does not depend on Android SDK readiness. New verified phone registration stops before the legacy vendor resolver and completes through the shared one-use native ticket. Check website-firebase-identity-test.php with OpenSSL enabled.
