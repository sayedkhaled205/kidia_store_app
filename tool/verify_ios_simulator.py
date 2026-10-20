"""Bounded launch check with Flutter logs and screenshot error detection."""
import argparse
import base64
import json
import os
from pathlib import Path
import re
import subprocess
import time
import uuid

FATAL_PATTERNS = {
    "invalid_saved_design": r"invalid\s+app[\s_]*design[\s_]*bundle",
    "provider_exception": r"provider\s*exception|provider\s+threw\s+the\s+following\s+exception",
    "flutter_exception": r"exception\s+caught\s+by|unhandled\s+(?:exception|error)",
    "flutter_engine_error": r"\[error:flutter/|could\s+not\s+prepare\s+isolate",
    "layout_overflow": r"(?:bottom|right|left|top)\s+overflowed\s+by|a\s+renderflex\s+overflowed",
}


def fatal_signals(value):
    return [name for name, pattern in FATAL_PATTERNS.items() if re.search(pattern, value, re.I)]


def normalized_text(value):
    return " ".join(re.findall(r"\w+", value.casefold()))


def storefront_evidence(lines, encoded_design=""):
    # These are actual application labels, not iOS permission-dialog text.
    labels = {
        "home", "category", "categories", "wishlist", "account", "search products",
        "الرئيسية", "الأقسام", "المفضلة", "حسابي", "البحث عن منتجات",
    }
    if encoded_design:
        try:
            design = json.loads(base64.b64decode(encoded_design, validate=True))
            blocks = design["home"]["blocks"]
            if not isinstance(blocks, list):
                raise ValueError()
        except (ValueError, KeyError, TypeError):
            raise ValueError("Saved design labels could not be read for startup inspection") from None

        def collect(value):
            if isinstance(value, dict):
                for key, child in value.items():
                    if key in {"title", "label", "button_label", "search_placeholder"} and isinstance(child, str):
                        labels.add(child)
                    elif isinstance(child, (dict, list)):
                        collect(child)
            elif isinstance(value, list):
                for child in value:
                    collect(child)

        for block in blocks:
            if isinstance(block, dict) and block.get("enabled", True):
                collect(block.get("data", {}))
    expected = {normalized_text(label) for label in labels if 4 <= len(label.strip()) <= 120}
    expected -= {"allow", "don t allow", "settings", "notifications"}
    visible = {normalized_text(line) for line in lines}
    return sorted(expected & visible)


def read_log(path):
    if not path.is_file():
        raise ValueError("Simulator application output was not captured")
    if path.stat().st_size > 10 * 1024 * 1024:
        raise ValueError("Simulator application output exceeded the bounded startup capture")
    return path.read_text(encoding="utf-8", errors="replace")


def verify(device, bundle, artifact_dir, runner=subprocess.run, sleeper=time.sleep, encoded_design=""):
    try:
        device = str(uuid.UUID(device)).upper()
    except ValueError:
        raise ValueError("Invalid iPhone simulator identifier") from None
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", bundle):
        raise ValueError("Invalid simulator application identifier")
    artifact_dir = Path(artifact_dir).resolve()
    artifact_dir.mkdir(parents=True, exist_ok=True)
    stdout = artifact_dir / "launch-stdout.log"
    stderr = artifact_dir / "launch-stderr.log"
    screenshot = artifact_dir / "launch.png"
    recognized = artifact_dir / "launch-screen-text.json"
    for path in (stdout, stderr, screenshot, recognized):
        path.unlink(missing_ok=True)
    stdout.touch()
    stderr.touch()
    result = runner([
        "xcrun", "simctl", "launch", "--terminate-running-process",
        "--stdout=" + str(stdout), "--stderr=" + str(stderr), device, bundle,
    ], capture_output=True, text=True)
    match = re.search(r"^" + re.escape(bundle) + r":\s+(\d+)\s*$", result.stdout, re.MULTILINE)
    if result.returncode or not match or int(match[1]) <= 0:
        raise ValueError("The simulator could not launch this store's application")
    pid = match[1]
    alive = True
    for _ in range(4):
        sleeper(3)
        process = runner(["ps", "-p", pid, "-o", "command="], capture_output=True, text=True)
        command = process.stdout.lower()
        if process.returncode or device.lower() not in command or "/runner.app/runner" not in command:
            alive = False
            break
    # Capture the actual screen before reporting failure, including a live error page.
    capture = runner(["xcrun", "simctl", "io", device, "screenshot", str(screenshot)], capture_output=True, text=True)
    if not alive:
        raise ValueError("The iOS application exited or failed its simulator launch check")
    if capture.returncode or not screenshot.is_file() or screenshot.read_bytes()[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("The simulator startup screenshot could not be captured")
    logs = read_log(stdout) + "\n" + read_log(stderr)
    signals = fatal_signals(logs)
    if signals:
        raise ValueError("Simulator startup errors in application logs: " + ", ".join(signals))
    # iOS debug output can legitimately omit Flutter's VM-service banner.
    # Screenshot inspection is mandatory even when the captured logs are empty.
    flutter_output = bool(re.search(r"Dart VM service is listening|flutter:", logs, re.I))
    ocr = runner([
        "xcrun", "swift", str(Path(__file__).with_name("ios_launch_ocr.swift")),
        str(screenshot), str(recognized),
    ], capture_output=True, text=True, timeout=60)
    if ocr.returncode or not recognized.is_file():
        raise ValueError("Simulator startup screen inspection failed")
    try:
        screen = json.loads(recognized.read_text(encoding="utf-8"))
        lines = screen["lines"]
        if not isinstance(lines, list) or not lines or any(not isinstance(line, str) for line in lines):
            raise ValueError()
    except (ValueError, KeyError, TypeError):
        raise ValueError("Simulator startup screen inspection returned no usable evidence") from None
    signals = fatal_signals("\n".join(lines))
    if signals:
        raise ValueError("Simulator startup error screen detected: " + ", ".join(signals))
    visible_storefront_labels = storefront_evidence(lines, encoded_design)
    if len(visible_storefront_labels) < 2:
        raise ValueError("Simulator screen has insufficient storefront evidence; a live PID or system dialog alone is insufficient")
    return {
        "status": "startup_no_detected_fatal_errors", "duration_seconds": 12,
        "bundle_id": bundle, "device_id": device, "process_alive": True,
        "application_logs_checked": True, "flutter_output_captured": flutter_output,
        "screenshot_inspected": True, "storefront_labels_matched": len(visible_storefront_labels),
        "recognized_lines": len(lines), "fatal_signals": [],
        "limitations": "Bounded startup check only; live login, checkout, payment and push remain unverified.",
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--device", required=True)
    parser.add_argument("--report", required=True, type=Path)
    args = parser.parse_args()
    args.report.parent.mkdir(parents=True, exist_ok=True)
    try:
        report = verify(args.device, os.environ["IOS_BUNDLE_ID"], args.report.parent,
                        encoded_design=os.environ.get("APP_DESIGN_BUNDLE", ""))
        args.report.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print("iOS startup logs and screen contain no detected fatal errors during the bounded check.")
    except (ValueError, OSError, KeyError, subprocess.SubprocessError) as error:
        message = str(error) if isinstance(error, ValueError) else "iOS simulator startup verification failed."
        args.report.write_text(json.dumps({"status": "failed", "reason": message}, indent=2), encoding="utf-8")
        raise SystemExit(message) from None
