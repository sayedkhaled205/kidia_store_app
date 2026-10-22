"""Apply public store identity to an isolated iOS build checkout."""
import argparse
import json
import os
import plistlib
import re
from pathlib import Path


def _google_auth_settings(bundle, native_auth=None, google_services_plist=None):
    """Read explicit auth input only; a push Firebase project is not auth setup."""
    if native_auth is not None and not isinstance(native_auth, dict):
        raise ValueError("Native authentication configuration must be an object")
    native_auth = native_auth or {}
    google = native_auth.get("google") or {}
    if not isinstance(google, dict):
        raise ValueError("Invalid native Google authentication configuration")
    client = google.get("ios_client_id") or None
    server = google.get("server_client_id") or None
    declared_bundle = google.get("ios_bundle_id")
    firebase = native_auth.get("firebase") or {}
    if not isinstance(firebase, dict):
        raise ValueError("Invalid native Firebase authentication configuration")
    firebase_ios = firebase.get("ios", firebase)
    if not isinstance(firebase_ios, dict):
        raise ValueError("Invalid native iOS authentication configuration")
    for claimed_bundle in (declared_bundle, firebase_ios.get("iosBundleId")):
        if claimed_bundle is not None and claimed_bundle != bundle:
            raise ValueError("Native authentication bundle does not match the build")

    plist = None
    if google_services_plist is not None:
        # The caller must supply this auth-specific file explicitly. Never
        # discover/reuse a default GoogleService-Info.plist for push implicitly.
        plist = plistlib.loads(Path(google_services_plist).read_bytes())
        if not isinstance(plist, dict) or plist.get("BUNDLE_ID") != bundle:
            raise ValueError("Google authentication plist bundle does not match the build")
        project = firebase_ios.get("projectId") or firebase.get("projectId")
        if project and plist.get("PROJECT_ID") != project:
            raise ValueError("Google authentication plist belongs to another Firebase project")
        plist_client = plist.get("CLIENT_ID")
        if client and plist_client != client:
            raise ValueError("Google authentication client IDs disagree")
        client = client or plist_client
        plist_server = plist.get("SERVER_CLIENT_ID")
        if server and plist_server and server != plist_server:
            raise ValueError("Google authentication server client IDs disagree")
        server = server or plist_server

    if client is None:
        if plist is not None or server is not None:
            raise ValueError("Native Google sign-in requires its iOS client ID")
        return None
    client_pattern = r"[A-Za-z0-9_-]+\.apps\.googleusercontent\.com"
    if not isinstance(client, str) or not re.fullmatch(client_pattern, client):
        raise ValueError("Invalid native Google iOS client ID")
    if server is not None and (not isinstance(server, str) or not re.fullmatch(client_pattern, server)):
        raise ValueError("Invalid native Google server client ID")
    reversed_client = ".".join(reversed(client.split(".")))
    if plist is not None and plist.get("REVERSED_CLIENT_ID") not in (None, reversed_client):
        raise ValueError("Google authentication reversed client ID does not match")
    return {"client": client, "server": server, "scheme": reversed_client}


def _apply_google_auth(info, settings):
    if settings is None:
        return
    for key, expected in (("GIDClientID", settings["client"]), ("GIDServerClientID", settings["server"])):
        if expected is not None:
            if key in info and info[key] != expected:
                raise ValueError("Existing Google configuration belongs to another app")
            info[key] = expected
    url_types = info.setdefault("CFBundleURLTypes", [])
    if not isinstance(url_types, list):
        raise ValueError("Invalid existing iOS URL scheme configuration")
    found = False
    for entry in url_types:
        if not isinstance(entry, dict) or not isinstance(entry.get("CFBundleURLSchemes", []), list):
            raise ValueError("Invalid existing iOS URL scheme entry")
        for scheme in entry.get("CFBundleURLSchemes", []):
            if not isinstance(scheme, str):
                raise ValueError("Invalid existing iOS URL scheme value")
            if scheme.startswith("com.googleusercontent.apps.") and scheme != settings["scheme"]:
                raise ValueError("Existing Google callback belongs to another app")
            found = found or scheme == settings["scheme"]
    if not found:
        url_types.append({
            "CFBundleTypeRole": "Editor",
            "CFBundleURLName": "com.mobishop.native-google-auth",
            "CFBundleURLSchemes": [settings["scheme"]],
        })


def configure(root, bundle, team, name, signing_required=True, native_auth=None, google_services_plist=None):
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", bundle):
        raise ValueError("Invalid iOS bundle identifier")
    if signing_required and not re.fullmatch(r"[A-Z0-9]{10}", team or ""):
        raise ValueError("Invalid Apple team identifier")
    if not signing_required and team is not None:
        raise ValueError("Simulator configuration must not import a signing identity")
    if not name.strip() or any(ord(c) < 32 for c in name):
        raise ValueError("Invalid display name")
    project = root / "ios/Runner.xcodeproj/project.pbxproj"
    source = project.read_text(encoding="utf-8")
    if source.count("PRODUCT_BUNDLE_IDENTIFIER = com.example.mobishopStoreApp;") != 3:
        raise ValueError("Unexpected Runner project identity; refusing partial update")
    source = source.replace(
        "PRODUCT_BUNDLE_IDENTIFIER = com.example.mobishopStoreApp;",
        f"PRODUCT_BUNDLE_IDENTIFIER = {bundle};" + (
            f"\n\t\t\t\tDEVELOPMENT_TEAM = {team};" if signing_required else ""
        ),
    ).replace("com.example.mobishopStoreApp.RunnerTests;", f"{bundle}.RunnerTests;")
    info_path = root / "ios/Runner/Info.plist"
    info = plistlib.loads(info_path.read_bytes())
    info["CFBundleDisplayName"] = name
    info["CFBundleName"] = name
    _apply_google_auth(info, _google_auth_settings(bundle, native_auth, google_services_plist))
    project.write_text(source, encoding="utf-8")
    info_path.write_bytes(plistlib.dumps(info, sort_keys=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--simulator", action="store_true")
    args = parser.parse_args()
    # These values are public OAuth client settings, supplied by the store's
    # authenticated native build configuration. They do not enable a provider.
    native_auth_json = os.environ.get("NATIVE_AUTH_CONFIG_JSON")
    native_auth = json.loads(native_auth_json) if native_auth_json else None
    google_services_plist = os.environ.get("NATIVE_AUTH_GOOGLE_SERVICES_PLIST") or None
    configure(Path.cwd(), os.environ["IOS_BUNDLE_ID"],
              None if args.simulator else os.environ["APPLE_TEAM_ID"],
              os.environ["STORE_NAME"], signing_required=not args.simulator,
              native_auth=native_auth, google_services_plist=google_services_plist)
