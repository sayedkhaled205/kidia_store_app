"""Bounded simulator launch smoke check; does not claim full app-flow success."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import time
import uuid


def verify(device, bundle, runner=subprocess.run, sleeper=time.sleep):
    try:
        device = str(uuid.UUID(device)).upper()
    except ValueError:
        raise ValueError("Invalid iPhone simulator identifier") from None
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", bundle):
        raise ValueError("Invalid simulator application identifier")
    result = runner(["xcrun", "simctl", "launch", "--terminate-running-process", device, bundle],
                    capture_output=True, text=True)
    match = re.search(r"^" + re.escape(bundle) + r":\s+(\d+)\s*$", result.stdout, re.MULTILINE)
    if result.returncode or not match or int(match[1]) <= 0:
        raise ValueError("The simulator could not launch this store's application")
    pid = match[1]
    # Simulator applications are host processes. Verify the returned process
    # belongs to this simulator and remains alive after launch, rather than
    # accepting simctl's initial PID as evidence against an immediate crash.
    for _ in range(4):
        sleeper(3)
        process = runner(["ps", "-p", pid, "-o", "command="], capture_output=True, text=True)
        command = process.stdout.lower()
        if process.returncode or device.lower() not in command or "/runner.app/runner" not in command:
            raise ValueError("The iOS application exited or failed its simulator launch check")
    return {"status": "launched_and_alive", "duration_seconds": 12,
            "bundle_id": bundle, "device_id": device}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--device", required=True)
    parser.add_argument("--report", required=True, type=Path)
    args = parser.parse_args()
    try:
        report = verify(args.device, os.environ["IOS_BUNDLE_ID"])
        args.report.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print("iOS simulator application remained alive for 12 seconds after launch.")
    except (ValueError, OSError, KeyError) as error:
        raise SystemExit(str(error) if isinstance(error, ValueError) else "iOS simulator launch verification failed.") from None
