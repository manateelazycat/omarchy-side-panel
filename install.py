#!/usr/bin/env python3
"""Install/restore the full bar while preserving the user's widget layout."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

PLUGIN_ID = "andy.side-panel"
SOURCE = Path(__file__).resolve().parent
FILES = ["manifest.json", "Bar.qml", "DockSurface.qml", "WidgetSlot.qml",
         "ActionIcon.qml", "ServiceBridge.qml", "SidePanelModel.js", "README.md", "LICENSE"]
STYLED_SERVICES = ["andy.language-switcher", "andy.display-reset", "io.github.manateelazycat.startup-map"]
STYLE_IMPORT = 'import "../andy.side-panel/Ui" as SidePanelUi // andy.side-panel popup style\n'


def style_service_popups(plugin_directory, state_directory, stamp, enabled):
    """Keep standalone service cards in the same style as the bar's popups.

    Only add an import and a reversible visual adapter. Remove our marked
    additions on restore, preserving any other edits made to the service.
    """
    adapted = 0
    for plugin_id in STYLED_SERVICES:
        path = plugin_directory / plugin_id / "Service.qml"
        if not path.exists():
            continue
        original = path.read_text()
        updated = original.replace(STYLE_IMPORT, "")
        updated = re.sub(r"(?m)^[ \t]*// BEGIN andy\.side-panel popup style\n.*?^[ \t]*// END andy\.side-panel popup style\n", "", updated, flags=re.S)
        if enabled:
            card = re.search(r"(?m)^([ \t]*)id: card[ \t]*$", updated)
            if not card:
                raise RuntimeError(f"Cannot locate the popup card in {path}")
            indent = card.group(1)
            hook = (f"\n{indent}// BEGIN andy.side-panel popup style\n"
                    f'{indent}SidePanelUi.PopupStyler {{ rootObject: card; label: "{plugin_id}" }}\n'
                    f"{indent}// END andy.side-panel popup style")
            updated = STYLE_IMPORT + updated[:card.end()] + hook + updated[card.end():]
            adapted += 1
        if updated == original:
            continue
        backup = state_directory / f"popup-services-{stamp}" / plugin_id / "Service.qml"
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, backup)
        descriptor, temporary = tempfile.mkstemp(prefix=".side-panel-style-", dir=path.parent)
        try:
            with os.fdopen(descriptor, "w") as stream:
                stream.write(updated)
            shutil.copymode(path, temporary)
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    return adapted


def atomic_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".side-panel-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as stream:
            json.dump(data, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def ipc(*args):
    return subprocess.run(["omarchy-shell", "shell", *args], check=True,
                          capture_output=True, text=True, timeout=30,
                          env={**os.environ, "OMARCHY_SHELL_IPC_TIMEOUT": "20s"}).stdout.strip()


def verify_activation():
    deadline = time.monotonic() + 15
    last_error = "plugin is not ready"
    while time.monotonic() < deadline:
        try:
            result = subprocess.run(["omarchy-shell", PLUGIN_ID, "status"],
                                    capture_output=True, text=True, timeout=3)
            status = json.loads(result.stdout)
            if status.get("id") == PLUGIN_ID and status.get("screens"):
                return len(status["screens"])
            last_error = result.stderr or result.stdout
        except (subprocess.TimeoutExpired, ValueError) as error:
            last_error = str(error)
        time.sleep(0.3)
    raise RuntimeError(last_error)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", nargs="?", choices=["install", "restore", "uninstall"], default="install")
    args = parser.parse_args()
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    state_home = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
    config_path = config_home / "omarchy/shell.json"
    destination = config_home / "omarchy/plugins" / PLUGIN_ID
    state_dir = state_home / "omarchy-side-panel"
    state_file = state_dir / "installation.json"
    ipc("ping")
    if not config_path.exists():
        defaults = Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy")) / "config/omarchy/shell.json"
        config = json.loads(defaults.read_text())
    else:
        config = json.loads(config_path.read_text())
    if config.get("version") != 1:
        raise SystemExit("Unsupported shell.json version; no changes made.")
    state_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    backup_path = state_dir / f"shell-{stamp}.json"
    atomic_json(backup_path, config)

    if args.action == "install":
        idle_status = subprocess.run(["omarchy", "toggle", "idle", "status"],
                                     check=True, capture_output=True, text=True, timeout=5)
        was_stay_awake = json.loads(idle_status.stdout)["enabled"] is True
        if not state_file.exists():
            previous = config.get("bar", {})
            atomic_json(state_file, {"previousBarId": previous.get("id", "omarchy.bar"),
                                    "previousPosition": previous.get("position", "top"),
                                    "backup": str(backup_path)})
        destination.parent.mkdir(parents=True, exist_ok=True)
        stage = Path(tempfile.mkdtemp(prefix=".side-panel-stage-", dir=state_dir))
        try:
            for name in FILES:
                shutil.copy2(SOURCE / name, stage / name)
            shutil.copytree(SOURCE / "Ui", stage / "Ui")
            shutil.copytree(SOURCE / "Icons", stage / "Icons")
            cache_home = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))
            (cache_home / "omarchy-side-panel/icons").mkdir(parents=True, exist_ok=True)
            if destination.exists():
                os.replace(destination, state_dir / f"plugin-{stamp}")
            os.replace(stage, destination)
        finally:
            if stage.exists():
                shutil.rmtree(stage)
        try:
            adapted_services = style_service_popups(destination.parent, state_dir, stamp, True)
            ipc("rescanPlugins")
            response = ipc("enablePlugin", PLUGIN_ID, "{}")
            if response != "ok":
                raise RuntimeError(response)
            # Qt can retain a full-bar entry in its component cache across a
            # plugin rescan. Restart through Omarchy's lock-aware command so
            # updates load the files just installed.
            subprocess.run(["omarchy", "restart", "shell"], check=True, timeout=30)
            screen_count = verify_activation()
            # Power Awake writes its state while services are starting. Apply
            # the pre-install state through the idle service as well, avoiding
            # a missed directory-watch event after a shell restart.
            subprocess.run(["omarchy-shell", "idle", "disable" if was_stay_awake else "enable"],
                           check=True, capture_output=True, text=True, timeout=5)
        except (RuntimeError, subprocess.SubprocessError) as error:
            try:
                previous_id = config.get("bar", {}).get("id", "omarchy.bar")
                if previous_id == PLUGIN_ID:
                    previous_id = json.loads(state_file.read_text())["previousBarId"]
                ipc("enablePlugin", previous_id, "{}")
                style_service_popups(destination.parent, state_dir, stamp, False)
            except subprocess.SubprocessError:
                pass
            raise SystemExit(f"Plugin activation failed: {error}. Config backup: {backup_path}")
        print(f"Installed and enabled {PLUGIN_ID} on {screen_count} screens\nStyled standalone panels: {adapted_services}\nConfig backup: {backup_path}")
    else:
        state = json.loads(state_file.read_text()) if state_file.exists() else {"previousBarId": "omarchy.bar"}
        if config.get("bar", {}).get("id") == PLUGIN_ID:
            response = ipc("enablePlugin", state["previousBarId"], "{}")
            if response != "ok":
                ipc("enablePlugin", "omarchy.bar", "{}")
        style_service_popups(destination.parent, state_dir, stamp, False)
        if args.action == "uninstall" and destination.exists():
            os.replace(destination, state_dir / f"uninstalled-{stamp}")
            ipc("rescanPlugins")
            state_file.unlink(missing_ok=True)
        print(f"Restored previous bar. Widget layout preserved.\nConfig backup: {backup_path}")


if __name__ == "__main__":
    main()
