# Builder connection recovery

On 28 October 2026 the live access log recorded two failed `PUT /account/builder/state`
requests at 10:43:16 and 10:44:19 UTC. Laravel logged connection timeouts to the
connected WooCommerce store's HTTPS endpoint in the same interval. PHP-FPM also
reached the API pool's five-worker limit. This establishes an outbound connection
failure and concurrent capacity pressure; it does not establish why the external
network connection failed or attribute it to a theme deployment.

`BuilderStoreRequest` makes one additional connection attempt only when actual
cURL measurements prove that no HTTP request was delivered. All measurements
must be present and zero: request bytes, upload bytes, response status, redirects,
pre-transfer time and first-response time. Only DNS/connect/timeout errors qualify.
Missing statistics, TLS errors, HTTP errors and a timeout after sending a request
never qualify. The recovery uses IPv4 without changing TLS verification, redirects,
credentials, payload or the existing total deadline. The normal first attempt
retains dual-stack behavior. No domain or customer is hard-coded in the fix.

The transport is shared by connector-backed application saves and WooCommerce/Odoo
catalog reads in the portal. Foreign-platform local design commits and Shopify's
existing connector path are unchanged. No merchant setting, theme snapshot or
mobile source is changed. An installed app does not need rebuilding for this fix.

## Validation and deployment

Run `php test_transport.php /path/to/vendor/autoload.php`. The script never boots
Laravel or accesses its database. It covers pre-delivery recovery, missing metrics,
delivered requests, TLS/HTTP errors, the two-attempt limit and the shared deadline.
It also uses the actual Laravel/cURL stack against a closed loopback port and a
loopback server that receives a POST but deliberately withholds its response.
All 36 checks passed on the deployment server with PHP 8.3.

From the WHM terminal, `python3 deploy.py --check` verifies current server hashes,
generates a narrow patch to the four existing catalog reads, lints all three PHP
files, and runs the tests. `--apply` repeats those checks, saves the original files
outside the web root and activates the files atomically. `--rollback` checks that
the deployed files still match before restoring the callers. It retains the unused
helper rather than deleting a potentially concurrently loaded file.

Separate operational change: increase only `api.woomobile.app`'s PHP-FPM pool from
5 to 10 workers through cPanel's supported API after backing up its pool configuration.
The server had about 44 GB available RAM. Keep max requests (20), idle timeout (10)
and other domains' pool settings unchanged. This addresses observed saturation;
it does not claim to repair an external network outage.

References: [Guzzle transfer statistics](https://docs.guzzlephp.org/en/stable/request-options.html#on-stats),
[cURL request size](https://curl.se/libcurl/c/CURLINFO_REQUEST_SIZE.html),
[cPanel pool tuning](https://support.cpanel.net/hc/en-us/articles/360036533754-How-to-modify-the-max-children-limit-for-PHP-FPM).
