"""Validate the public native-auth capability used by iOS configuration/signing."""
import json
import re
from pathlib import Path


def facebook_settings(config):
    if not config or config.get('methods', {}).get('facebook_native') is not True:
        return None
    source = config.get('facebook')
    if (not isinstance(source, dict)
            or not isinstance(source.get('app_id'), str)
            or not re.fullmatch(r'[1-9][0-9]{0,63}', source['app_id'])
            or not isinstance(source.get('client_token'), str)
            or not re.fullmatch(r'[A-Za-z0-9_-]{16,512}', source['client_token'])):
        raise ValueError('Native Facebook requires public app ID and client token.')
    # The Meta app secret remains exclusively on the merchant server.
    return {key: source[key] for key in ('app_id', 'client_token')}


def apple_required(config=None, required=False):
    if config is None:
        if required:
            raise ValueError("Apple sign-in requires explicit native authentication configuration")
        return False
    if not isinstance(config, dict):
        raise ValueError("Native authentication configuration must be an object")
    methods = config.get("methods", {})
    if not isinstance(methods, dict):
        raise ValueError("Native authentication methods must be an object")
    apple = methods.get("apple", False)
    if not isinstance(apple, bool):
        raise ValueError("Apple authentication capability must be a boolean")
    if required and not apple:
        raise ValueError("Required Apple authentication capability is missing")
    return apple


def from_environment(environment):
    raw = environment.get("NATIVE_AUTH_CONFIG_JSON")
    required = environment.get("APPLE_SIGN_IN_REQUIRED", "false")
    if required not in ("true", "false"):
        raise ValueError("Apple sign-in requirement must be true or false")
    snapshot = environment.get("NATIVE_AUTH_CONFIG_FILE")
    if snapshot:
        from native_build_defines81 import load_json, origin
        value = load_json(Path(snapshot).read_text(encoding="utf-8"))
        platform = environment.get("STORE_PLATFORM", "woocommerce").strip().lower()
        if (not isinstance(value, dict) or value.get("version") != 1
                or value.get("store_url") != origin(environment.get("STORE_URL", ""), clean=platform != "woocommerce")
                or value.get("platform") != platform
                or value.get("ios_bundle_id") != environment.get("IOS_BUNDLE_ID")
                or value.get("android_application_id") != environment.get("ANDROID_APPLICATION_ID")
                or not isinstance(value.get("config"), dict)):
            raise ValueError("Frozen native authentication configuration belongs to another build")
        config = value["config"]
    else:
        config = json.loads(raw) if raw else None
    apple_required(config, required == "true")
    return config
