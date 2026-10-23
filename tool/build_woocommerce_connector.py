#!/usr/bin/env python3
"""Build the canonical WooMobile connector, independently of the legacy CMS plugin."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = Path('connectors/woocommerce/source-manifest.json')
SLUG = 'mobi2app-connector'


def relative_path(value: str) -> PurePosixPath:
    path = PurePosixPath(value)
    if not value or not path.parts or '\\' in value or ':' in value or path.is_absolute() or '..' in path.parts or path.as_posix() != value:
        raise ValueError(f'Unsafe package path: {value}')
    return path


def verify_features(files: dict[str, bytes], manifest: dict) -> None:
    """Fail packaging if an authentication or automatic setup module disappeared."""
    if manifest.get('schema') != 1 or manifest.get('slug') != SLUG:
        raise ValueError('Unsupported connector manifest or plugin slug')
    version = manifest.get('version', '')
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('Invalid connector version')
    private_material = re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|(?<![A-Za-z0-9])(?:ghp_|gho_|github_pat_)[A-Za-z0-9_]{25,}')
    for name, data in files.items():
        path = relative_path(name)
        if (set(path.parts) & {'.git', '.github', 'tests', 'node_modules', '__pycache__'}
                or path.name.startswith('.env')
                or path.suffix.lower() in {'.pem', '.key', '.p8', '.p12', '.mobileprovision', '.keystore', '.jks', '.zip', '.log', '.sqlite'}):
            raise ValueError(f'Private, development or nested archive file cannot ship: {name}')
        if private_material.search(data):
            raise ValueError(f'Private key or access-token pattern cannot ship: {name}')
    required = {
        'mobi2app-connector.php': [f'Version:           {version}', "'MOBISHOP_VERSION'", f"'{version}'"],
        'readme.txt': [f'Stable tag: {version}'],
        'api/class-customer-auth-endpoint.php': ["'/class-website-auth-endpoint.php'", 'new MobiShop_Website_Auth_Endpoint', '$website->register()', 'issue_session_response', 'is_allowed_customer'],
        'api/class-website-auth-endpoint.php': ['/auth/website/', "'config' => 'GET'", "'start' => 'POST'", "'exchange' => 'POST'", "'wp_login'", 'hash_equals', 'challenge', "wc_get_page_id( 'myaccount' )"],
        'includes/class-mobishop.php': ['includes/central/loader.php', 'class-customer-auth-endpoint.php', 'MobiShop_Customer_Auth_Endpoint'],
        'includes/central/loader.php': ['bootstrap.php', 'store-data.php', 'kidia-push-admin-bridge.php', 'kidia-builder-application-bridge.php', 'store-notifications.php'],
        'includes/central/store-notifications.php': ['/central/notifications-connection', "current_user_can('manage_options')", "current_user_can('manage_woocommerce')", "'redirection'=>0", 'self::BASE', 'self::connection()'],
        'includes/central/bootstrap.php': ['/central/capabilities', '/central/bootstrap', "current_user_can('manage_options')", "current_user_can('manage_woocommerce')", '$manager->activate', 'native_checkout_setup', 'MobiShop_Native_Checkout_Setup50::prepare()'],
        'includes/class-native-checkout-setup50.php': ["current_user_can( 'manage_options' )", "current_user_can( 'manage_woocommerce' )", 'MobiShop_License_Manager', 'GET_LOCK', 'key_fingerprint', 'installation_sql()', 'hash_equals'],
        'includes/class-native-checkout-bootstrap50.php': ['MobiShop_Native_Checkout_Setup50::runtime_enabled()', 'native-checkout-capabilities', 'fail_closed'],
        'api/class-native-checkout-safety50.php': ['key_configured()', 'installation_sql()', 'key_fingerprint', 'defer_online_payment', 'handoff_payment', 'restore_payment_hook'],
        'api/class-customer-orders-endpoint.php': ['/customer/orders/(?P<id>\\d+)', "'get_order'", "'authenticate_customer'", "'needs_payment'", "'is_paid'", "'payment_url'", "'payment_method'", "'payment_endpoint_path'", "wc_get_endpoint_url( 'order-pay'"],
        'api/class-checkout-config-endpoint.php': ["'payment_methods'", 'payment_method_labels()', 'payment_gateways()', 'get_title()', 'no-store', "'options_by_country'", 'get_shipping_countries()', 'get_allowed_countries()'],
        'includes/central/store-data.php': ['/central/store-data', 'permission_callback'],
        'includes/central/kidia-push-admin-bridge.php': ['/builder/push-status', '/builder/push-actions', 'permission_callback'],
        'includes/central/kidia-builder-application-bridge.php': ['/builder/application-state', 'permission_callback'],
    }
    for path, markers in required.items():
        if path not in files:
            raise ValueError(f'Required connector module missing: {path}')
        source = files[path].decode('utf-8')
        for marker in markers:
            if marker not in source:
                raise ValueError(f'Required connector registration missing in {path}: {marker}')
    if 'mobishop.php' in files or any(path.startswith('mobishop/') for path in files):
        raise ValueError('Legacy CMS bootstrap must not ship in the API connector')


def load_sources(root: Path = ROOT) -> tuple[dict, dict[str, bytes]]:
    manifest = json.loads((root / MANIFEST).read_text(encoding='utf-8'))
    files = {}
    for name, record in manifest['files'].items():
        relative_path(name)
        source = relative_path(record['source'])
        if not (source.as_posix().startswith('connectors/woocommerce/source/') or source.as_posix().startswith('mobishop/')):
            raise ValueError(f'Unexpected source directory: {source}')
        path = root / source
        if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
            raise ValueError(f'Source escapes the repository: {source}')
        data = path.read_bytes()
        newline = record.get('newline', 'binary')
        if newline not in {'binary', 'lf', 'crlf'}:
            raise ValueError(f'Unsupported source newline representation: {source}')
        if newline != 'binary':
            data = data.replace(b'\r\n', b'\n')
        if hashlib.sha256(data).hexdigest() != record['source_sha256']:
            raise ValueError(f'Source differs from reviewed connector manifest: {source}. Review the change and update its pinned hash.')
        if newline == 'crlf':
            data = data.replace(b'\n', b'\r\n')
        if hashlib.sha256(data).hexdigest() != record['sha256']:
            raise ValueError(f'Reconstructed connector file differs from the reviewed release: {name}')
        files[name] = data
    verify_features(files, manifest)
    return manifest, files


def write_package(manifest: dict, files: dict[str, bytes], output: Path) -> Path:
    verify_features(files, manifest)
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f'{SLUG}-{manifest["version"]}.zip'
    # Deterministic metadata makes independent CI builds verifiable by checksum.
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as package:
        for name, data in sorted(files.items()):
            relative_path(name)
            info = zipfile.ZipInfo(f'{SLUG}/{name}', date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            package.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    with zipfile.ZipFile(archive) as package:
        if set(package.namelist()) != {f'{SLUG}/{name}' for name in files}:
            raise ValueError('Connector archive inventory differs from the reviewed manifest')
        for name, data in files.items():
            if package.read(f'{SLUG}/{name}') != data:
                raise ValueError(f'Packaged source differs: {name}')
    metadata = {'slug': SLUG, 'version': manifest['version'], 'file': archive.name,
                'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(), 'files': len(files)}
    (output / 'connector-release.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
    return archive


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'build/woocommerce')
    parser.add_argument('--verify-only', action='store_true')
    args = parser.parse_args()
    manifest, files = load_sources()
    if args.verify_only:
        print(f'Connector {manifest["version"]}: {len(files)} reviewed source files verified.')
    else:
        print(write_package(manifest, files, args.output))


if __name__ == '__main__':
    main()
