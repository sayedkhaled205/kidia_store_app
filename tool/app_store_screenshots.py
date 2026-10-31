"""Capture the actual saved storefront on App Store-sized Apple simulators."""
import json
import os
from pathlib import Path
import struct
import subprocess

from verify_ios_simulator import verify


DEVICES = {
    "iphone": ("iPhone 17 Pro Max", "iPhone 16 Pro Max", "iPhone 15 Pro Max", "iPhone 14 Pro Max"),
    "ipad": ("iPad Pro 13-inch (M5)", "iPad Pro 13-inch (M4)", "iPad Pro (12.9-inch) (6th generation)"),
}
SIZES = {"iphone": {(1320, 2868), (1290, 2796)}, "ipad": {(2064, 2752), (2048, 2732)}}


def select_devices(inventory):
    available = [device for runtime, devices in inventory["devices"].items()
                 if ".iOS-" in runtime for device in devices if device.get("isAvailable")]
    selected = {}
    for family, names in DEVICES.items():
        match = next((device for name in names for device in available if device["name"] == name), None)
        if match is None:
            raise ValueError(f"No supported App Store {family} simulator is available")
        selected[family] = match
    return selected


def capture(app, destination):
    inventory = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))
    selected = select_devices(inventory)
    for family, device in selected.items():
        identifier = device["udid"]
        if device.get("state") != "Booted":
            subprocess.run(["xcrun", "simctl", "boot", identifier], check=True)
        try:
            subprocess.run(["xcrun", "simctl", "bootstatus", identifier, "-b"], check=True)
            subprocess.run(["xcrun", "simctl", "install", identifier, str(app)], check=True)
            folder = destination / family
            report = verify(identifier, os.environ["IOS_BUNDLE_ID"], folder,
                            encoded_design=os.environ.get("APP_DESIGN_BUNDLE", ""))
            image = (folder / "launch.png").read_bytes()
            size = struct.unpack(">II", image[16:24])
            if size not in SIZES[family]:
                raise ValueError(f"Unexpected App Store {family} screenshot dimensions: {size}")
            report.update(device_name=device["name"], screenshot_dimensions=list(size))
            (folder / "launch-check.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        finally:
            subprocess.run(["xcrun", "simctl", "shutdown", identifier], check=False)


if __name__ == "__main__":
    capture(Path("build/ios/iphonesimulator/Runner.app"), Path("build/ios/simulator-artifacts"))
