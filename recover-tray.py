#!/usr/bin/env python3
"""Restore live, protocol-named SNI items after their watcher restarts."""
import json
import re
import subprocess

WATCHER = "org.kde.StatusNotifierWatcher"
WATCHER_PATH = "/StatusNotifierWatcher"
ITEM_PATH = "/StatusNotifierItem"
ITEM_INTERFACE = "org.kde.StatusNotifierItem"
ITEM_NAME = re.compile(r"^org\.(?:kde|freedesktop)\.StatusNotifierItem-\d+-\d+$")


def busctl(*arguments):
    result = subprocess.run(
        ["busctl", "--user", "--timeout=2s", "--json=short", *arguments],
        capture_output=True, text=True, check=True, timeout=3)
    return json.loads(result.stdout) if result.stdout.strip() else None


def identity(item, owners):
    service, separator, path = item.partition("/")
    return owners.get(service, service), "/" + path if separator else ITEM_PATH


def recover():
    # List only acquired names: probing an activatable name could launch an app.
    owners = {entry["name"]: entry["connection"] for entry in busctl("--acquired", "list")
              if (entry.get("connection") or "").startswith(":")}
    watcher = owners.get(WATCHER)
    if not watcher:
        return {"watcher": False, "recovered": [], "pending": 0, "error": ""}

    # Pin calls to this watcher's unique owner. An owner change during a scan
    # must not send a stale snapshot to its replacement.
    registered = busctl("get-property", watcher, WATCHER_PATH, WATCHER,
                       "RegisteredStatusNotifierItems")["data"]
    present = {identity(item, owners) for item in registered}
    candidates = {}
    for name, owner in sorted(owners.items()):
        if ITEM_NAME.fullmatch(name):
            candidates.setdefault((owner, ITEM_PATH), name)

    recovered, pending = [], 0
    for key, name in candidates.items():
        if key in present:
            continue
        try:
            # A name may appear before its object is exported. Only register
            # an actual SNI interface; the next scan retries unfinished apps.
            busctl("get-property", key[0], ITEM_PATH, ITEM_INTERFACE, "Id")
            # Confirm the alias still belongs to the object we just checked.
            owner = busctl("call", "org.freedesktop.DBus", "/org/freedesktop/DBus",
                           "org.freedesktop.DBus", "GetNameOwner", "s", name)["data"][0]
            if owner != key[0]:
                pending += 1
                continue
            busctl("call", watcher, WATCHER_PATH, WATCHER,
                   "RegisterStatusNotifierItem", "s", name)
        except (subprocess.SubprocessError, OSError):
            pending += 1
            continue
        recovered.append(name)
        present.add(key)
    return {"watcher": True, "recovered": recovered, "pending": pending, "error": ""}


def main():
    try:
        result = recover()
    except (subprocess.SubprocessError, OSError, ValueError, KeyError, TypeError) as error:
        print(json.dumps({"watcher": False, "recovered": [], "pending": 0,
                          "error": str(error)}), flush=True)
        return 1
    print(json.dumps(result), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
