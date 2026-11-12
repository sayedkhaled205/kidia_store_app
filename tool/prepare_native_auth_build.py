"""Freeze public native SDK settings before configuration and signing validation."""
import argparse
import json
import os
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import HTTPRedirectHandler, Request, build_opener

from native_auth_build import apple_required, facebook_settings
from native_build_defines81 import PLATFORMS, load_json, origin


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *_args, **_kwargs):
        raise ValueError('Native authentication configuration must use the configured store directly.')


def fetch_public_config(url):
    try:
        request = Request(url, headers={'Accept': 'application/json',
                                        'User-Agent': 'WooMobile-Native-Build/1.0'})
        with build_opener(NoRedirect).open(request, timeout=20) as response:
            body = response.read(65537)
    except HTTPError as error:
        if error.code == 404:
            # Legacy connectors expose no native providers, matching the app.
            return {'version': 1, 'enabled': False, 'methods': {}}
        raise ValueError('Could not read public native authentication configuration.') from None
    if len(body) > 65536:
        raise ValueError('Native authentication configuration is too large.')
    return load_json(body.decode('utf-8'))


def prepare(environment, output, fetcher=fetch_public_config):
    platform = environment.get('STORE_PLATFORM', 'woocommerce').strip().lower()
    if platform not in PLATFORMS:
        raise ValueError('Unsupported store platform.')
    store = origin(environment.get('STORE_URL', ''), clean=platform != 'woocommerce')
    raw = environment.get('NATIVE_AUTH_CONFIG_JSON')
    if raw:
        config = load_json(raw)
    elif platform == 'woocommerce':
        target = 'ios' if environment.get('IOS_BUNDLE_ID') else 'android'
        query = target + ('&ios_phone_callback_version=1' if target == 'ios' else '')
        config = fetcher(store + '/wp-json/mobishop/v1/auth/native/config?platform=' + query)
        if (not isinstance(config, dict) or config.get('version') != 1
                or type(config.get('enabled')) is not bool
                or not isinstance(config.get('methods'), dict)):
            raise ValueError('Invalid public native authentication configuration.')
    else:
        # Other commerce adapters do not use WooCommerce authentication routes.
        config = {'methods': {}}
    required = environment.get('APPLE_SIGN_IN_REQUIRED', 'false')
    if required not in ('true', 'false'):
        raise ValueError('Invalid Apple sign-in requirement.')
    apple_required(config, required == 'true')
    # Retain only public inputs actually consumed by configure_ios_store. Never
    # copy sessions, provider secrets or customer data into a build snapshot.
    selected = {'methods': {'apple': apple_required(config)}}
    facebook = facebook_settings(config)
    if platform == 'woocommerce' and environment.get('IOS_BUNDLE_ID') and environment.get('ANDROID_APPLICATION_ID') and not raw:
        android = fetcher(store + '/wp-json/mobishop/v1/auth/native/config?platform=android')
        if (not isinstance(android, dict) or android.get('version') != 1
                or type(android.get('enabled')) is not bool or not isinstance(android.get('methods'), dict)):
            raise ValueError('Invalid public Android authentication configuration.')
        android_facebook = facebook_settings(android)
        if facebook and android_facebook and facebook != android_facebook:
            raise ValueError('Facebook identities must match across the store build.')
        facebook = facebook or android_facebook
    if facebook:
        selected['methods']['facebook_native'] = True
        selected['facebook'] = facebook
    for section, keys in (
        ('google', ('ios_client_id', 'server_client_id', 'ios_bundle_id')),
        ('firebase', ('iosBundleId', 'projectId', 'appId')),
    ):
        source = config.get(section) or (config.get('ios_phone_callback') if section == 'firebase' else None) or {}
        if not isinstance(source, dict):
            raise ValueError('Invalid public native authentication settings.')
        if section == 'firebase' and 'ios' in source:
            source = source['ios']
        if not isinstance(source, dict):
            raise ValueError('Invalid iOS authentication settings.')
        selected[section] = {key: source[key] for key in keys if source.get(key) is not None}
        if any(not isinstance(value, str) or len(value) > 512 for value in selected[section].values()):
            raise ValueError('Invalid public iOS client setting.')
    # Reuse the existing bundle/client validation before writing any snapshot.
    from configure_ios_store import _google_auth_settings, _apply_firebase_auth_callback
    google = (_google_auth_settings(environment['IOS_BUNDLE_ID'], selected,
                                  environment.get('NATIVE_AUTH_GOOGLE_SERVICES_PLIST') or None)
              if environment.get('IOS_BUNDLE_ID') else None)
    if environment.get('IOS_BUNDLE_ID') and config.get('methods', {}).get('google') is True and google is None:
        raise ValueError('Enabled Google sign-in requires its iOS client settings.')
    if environment.get('IOS_BUNDLE_ID'):
        _apply_firebase_auth_callback({}, selected)
    if google:
        selected['google']['ios_client_id'] = google['client']
        if google['server']:
            selected['google']['server_client_id'] = google['server']
    value = {'version': 1, 'store_url': store, 'platform': platform,
             'ios_bundle_id': environment.get('IOS_BUNDLE_ID'),
             'android_application_id': environment.get('ANDROID_APPLICATION_ID'), 'config': selected}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(value, ensure_ascii=True), encoding='utf-8')
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--env-file', required=True, type=Path)
    args = parser.parse_args()
    try:
        prepare(os.environ, args.output)
        path = str(args.output.resolve())
        if '\n' in path or '\r' in path:
            raise ValueError('Invalid native configuration snapshot path.')
        with args.env_file.open('a', encoding='utf-8') as target:
            target.write('\nNATIVE_AUTH_CONFIG_FILE=' + path + '\n')
    except Exception:
        # Do not echo URLs, response bodies or provider inputs on failed reads.
        raise SystemExit('Native sign-in configuration could not be frozen; no build was started.') from None
    print('Public native sign-in configuration frozen for this store and app identity.')


if __name__ == '__main__':
    main()
