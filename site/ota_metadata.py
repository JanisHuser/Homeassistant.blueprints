#!/usr/bin/env python3
"""Describes a Matter OTA image for Home Assistant's Matter Server, which offers the update to matching devices.

Usage: ota_metadata.py <image.ota> <sdkconfig> <CMakeLists.txt>  (writes the JSON to stdout)

The Matter Server reads every *.json in its updates folder at startup (add-on:
/addon_configs/core_matter_server/updates/) and serves the .ota that otaUrl names from the same folder.
"""
import base64
import hashlib
import json
import pathlib
import re
import sys

OTA_CHECKSUM_SHA256 = 1


def config_value(text, key):
    match = re.search(rf"^{key}=(.*)$", text, re.MULTILINE)
    if not match:
        sys.exit(f"{key} missing")
    return match.group(1).strip('"')


def main():
    image, sdkconfig, cmakelists = (pathlib.Path(arg) for arg in sys.argv[1:4])
    config = sdkconfig.read_text()
    cmake = cmakelists.read_text()
    version_string = re.search(r'set\(PROJECT_VER "(.*)"\)', cmake).group(1)
    version = int(re.search(r"set\(PROJECT_VER_NUMBER (\d+)\)", cmake).group(1))
    digest = hashlib.sha256(image.read_bytes()).digest()
    metadata = {
        "modelVersion": {
            "vid": int(config_value(config, "CONFIG_DEVICE_VENDOR_ID"), 0),
            "pid": int(config_value(config, "CONFIG_DEVICE_PRODUCT_ID"), 0),
            "softwareVersion": version,
            "softwareVersionString": version_string,
            "minApplicableSoftwareVersion": 0,
            # A device takes only a newer version than it runs.
            "maxApplicableSoftwareVersion": version - 1,
            "otaUrl": f"file:///{image.name}",
            "otaChecksum": base64.b64encode(digest).decode(),
            "otaChecksumType": OTA_CHECKSUM_SHA256,
            "otaFileSize": image.stat().st_size,
        }
    }
    json.dump(metadata, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()
