#!/usr/bin/env bash
# Prints the UDID of one available iPad simulator on the newest installed iOS runtime.
# Preference: iPad Pro 13-inch (M4) > any iPad Pro > any iPad. If no iPad device exists yet
# (fresh local Xcode), creates "DFET Trainer iPad" from the best iPad device type.
# Only the UDID goes to stdout; diagnostics go to stderr.
set -euo pipefail

python3 - <<'PY'
import json, re, subprocess, sys

def simctl(*args):
    return subprocess.run(["xcrun", "simctl", *args], check=True, capture_output=True, text=True).stdout

def version_key(identifier):
    m = re.search(r"iOS-(\d+)-(\d+)(?:-(\d+))?$", identifier)
    return tuple(int(x or 0) for x in m.groups()) if m else (0, 0, 0)

def is_ipad(device_type_identifier):
    return ".SimDeviceType.iPad" in device_type_identifier

def rank(type_identifier):
    kind = type_identifier.split(".SimDeviceType.")[-1]
    if kind.startswith("iPad-Pro-13-inch-M4"):
        return 0
    if kind.startswith("iPad-Pro"):
        return 1
    return 2

runtimes = [r for r in json.loads(simctl("list", "runtimes", "--json"))["runtimes"]
            if r.get("isAvailable") and r["identifier"].split(".")[-1].startswith("iOS-")]
if not runtimes:
    sys.exit("ci_pick_ipad: no available iOS simulator runtime")
runtimes.sort(key=lambda r: version_key(r["identifier"]), reverse=True)

devices = json.loads(simctl("list", "devices", "available", "--json"))["devices"]
for runtime in runtimes:
    ipads = [d for d in devices.get(runtime["identifier"], [])
             if is_ipad(d.get("deviceTypeIdentifier", "")) and d.get("isAvailable", True)]
    if ipads:
        ipads.sort(key=lambda d: (rank(d["deviceTypeIdentifier"]), d["deviceTypeIdentifier"], d["name"]))
        chosen = ipads[0]
        print(f"ci_pick_ipad: {chosen['name']} ({runtime['name']})", file=sys.stderr)
        print(chosen["udid"])
        sys.exit(0)

runtime = runtimes[0]
supported = runtime.get("supportedDeviceTypes") or json.loads(simctl("list", "devicetypes", "--json"))["devicetypes"]
types = [t for t in supported if is_ipad(t["identifier"])]
if not types:
    sys.exit(f"ci_pick_ipad: {runtime['name']} supports no iPad device type")
types.sort(key=lambda t: (rank(t["identifier"]), t["identifier"]))
udid = simctl("create", "DFET Trainer iPad", types[0]["identifier"], runtime["identifier"]).strip()
print(f"ci_pick_ipad: created DFET Trainer iPad ({types[0]['name']}, {runtime['name']})", file=sys.stderr)
print(udid)
PY
