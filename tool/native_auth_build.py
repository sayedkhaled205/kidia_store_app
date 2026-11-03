"""Validate the public native-auth capability used by iOS configuration/signing."""
import json


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
    config = json.loads(raw) if raw else None
    apple_required(config, required == "true")
    return config
