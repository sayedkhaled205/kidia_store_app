"""Apply public store identity to an isolated iOS build checkout."""
import os
import plistlib
import re
from pathlib import Path


def configure(root, bundle, team, name):
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", bundle):
        raise ValueError("Invalid iOS bundle identifier")
    if not re.fullmatch(r"[A-Z0-9]{10}", team):
        raise ValueError("Invalid Apple team identifier")
    if not name.strip() or any(ord(c) < 32 for c in name):
        raise ValueError("Invalid display name")
    project = root / "ios/Runner.xcodeproj/project.pbxproj"
    source = project.read_text(encoding="utf-8")
    if source.count("PRODUCT_BUNDLE_IDENTIFIER = com.example.mobishopStoreApp;") != 3:
        raise ValueError("Unexpected Runner project identity; refusing partial update")
    source = source.replace(
        "PRODUCT_BUNDLE_IDENTIFIER = com.example.mobishopStoreApp;",
        f"PRODUCT_BUNDLE_IDENTIFIER = {bundle};\n\t\t\t\tDEVELOPMENT_TEAM = {team};",
    ).replace("com.example.mobishopStoreApp.RunnerTests;", f"{bundle}.RunnerTests;")
    info_path = root / "ios/Runner/Info.plist"
    info = plistlib.loads(info_path.read_bytes())
    info["CFBundleDisplayName"] = name
    info["CFBundleName"] = name
    project.write_text(source, encoding="utf-8")
    info_path.write_bytes(plistlib.dumps(info, sort_keys=False))


if __name__ == "__main__":
    configure(Path.cwd(), os.environ["IOS_BUNDLE_ID"], os.environ["APPLE_TEAM_ID"], os.environ["STORE_NAME"])
