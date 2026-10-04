"""Exercise real SNI recovery on a private bus without touching desktop apps."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

SOURCE = Path(__file__).resolve().parents[1]
WATCHER = "org.kde.StatusNotifierWatcher"


def export_item(index, delay):
    # Gio is only a test dependency; the installed helper uses the stdlib.
    from gi.repository import Gio, GLib

    connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    properties = {
        "Id": ("s", f"recovery-test-{index}"), "Title": ("s", "Recovery test"),
        "Category": ("s", "ApplicationStatus"), "Status": ("s", "Active"),
        "WindowId": ("i", 0), "IconName": ("s", "application-x-executable"),
        "IconPixmap": ("a(iiay)", []), "IconThemePath": ("s", ""),
        "OverlayIconName": ("s", ""), "OverlayIconPixmap": ("a(iiay)", []),
        "AttentionIconName": ("s", ""), "AttentionIconPixmap": ("a(iiay)", []),
        "AttentionMovieName": ("s", ""), "ItemIsMenu": ("b", False), "Menu": ("o", "/"),
        "ToolTip": ("(sa(iiay)ss)", ("", [], "Recovery test", "")),
    }
    xml = '<node><interface name="org.kde.StatusNotifierItem">' + "".join(
        f'<property name="{name}" type="{signature}" access="read"/>'
        for name, (signature, _) in properties.items()) + "</interface></node>"
    interface = Gio.DBusNodeInfo.new_for_xml(xml).interfaces[0]

    def export():
        connection.register_object("/StatusNotifierItem", interface, None,
                                   lambda _, __, ___, ____, name: GLib.Variant(*properties[name]), None)
        return False

    for prefix in ("org.kde", "org.freedesktop"):
        reply = connection.call_sync(
            "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "RequestName",
            GLib.Variant("(su)", (f"{prefix}.StatusNotifierItem-{os.getpid()}-{index}", 4)),
            GLib.VariantType.new("(u)"), Gio.DBusCallFlags.NONE, 2000, None)
        assert reply.unpack()[0] == 1
    if delay:
        GLib.timeout_add(int(delay * 1000), export)
    else:
        export()
    GLib.MainLoop().run()


def wait_for(predicate, message, timeout=8):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.05)
    raise AssertionError(message)


def registered():
    result = subprocess.run([
        "busctl", "--user", "--timeout=1s", "--json=short", "get-property",
        WATCHER, "/StatusNotifierWatcher", WATCHER, "RegisteredStatusNotifierItems"],
        capture_output=True, text=True, timeout=2)
    return json.loads(result.stdout)["data"] if result.returncode == 0 else []


def stop(process):
    if process and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)


def session():
    processes = []
    with tempfile.TemporaryDirectory(prefix="side-panel-tray-") as directory:
        # Include a space to verify the helper's resolved file URL is decoded.
        root = Path(directory) / "test shell"
        plugin = root / "Plugin"
        plugin.mkdir(parents=True)
        for name in ("TrayRecovery.qml", "recover-tray.py"):
            shutil.copy2(SOURCE / name, plugin / name)
        (plugin / "qmldir").write_text("TrayRecovery 1.0 TrayRecovery.qml\n")
        (root / "shell.qml").write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "Plugin" as Plugin
ShellRoot {
    Plugin.TrayRecovery { id: recovery }
    IpcHandler {
        target: "tray-test"
        function status(): string { return JSON.stringify(recovery.snapshot()); }
        function rescan(): void { recovery.requestScan(); }
    }
}
''')
        environment = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
                       "QT_LOGGING_RULES": "", "QS_DISABLE_FILE_WATCHER": "1",
                       "QT_QPA_PLATFORMTHEME": "", "GIO_USE_VFS": "local",
                       "QT_ACCESSIBILITY": "0", "NO_AT_BRIDGE": "1"}
        with (root / "shell.log").open("w+") as log:
            def launch_shell():
                process = subprocess.Popen(["quickshell", "-n", "-p", str(root), "--no-color"],
                                           stdout=log, stderr=log, env=environment)
                processes.append(process)
                return process

            def ipc(method):
                return subprocess.run(["quickshell", "ipc", "-p", str(root), "call", "tray-test", method],
                                      capture_output=True, text=True, timeout=2)

            def status():
                result = ipc("status")
                return json.loads(result.stdout) if result.returncode == 0 else {}

            def exporter(index, delay=0):
                process = subprocess.Popen([sys.executable, str(Path(__file__).resolve()),
                                            "--export-item", str(index), str(delay)],
                                           stdout=log, stderr=log)
                processes.append(process)
                return process

            try:
                first = exporter(1)
                # Ensure an existing item precedes the watcher, as with Catlink.
                name = f"org.kde.StatusNotifierItem-{first.pid}-1"
                wait_for(lambda: subprocess.run([
                    "busctl", "--user", "--timeout=1s", "call", "org.freedesktop.DBus",
                    "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetNameOwner", "s", name],
                    capture_output=True, timeout=2).returncode == 0, "Item did not acquire its name")
                shell = launch_shell()
                wait_for(lambda: len(registered()) == 1 and status().get("recoveredCount") == 1,
                         "Startup did not restore the existing item")
                assert status()["monitoring"]
                scans = status()["scans"]
                assert ipc("rescan").returncode == 0
                wait_for(lambda: status().get("scans", 0) > scans, "Deduplication scan did not finish")
                assert status()["recoveredCount"] == 1
                assert len(registered()) == 1
                print("Startup recovery and alias deduplication passed", flush=True)

                stop(shell)
                assert first.poll() is None
                shell = launch_shell()
                wait_for(lambda: len(registered()) == 1 and status().get("recoveredCount") == 1,
                         "Watcher restart did not restore the surviving item")
                print("Shell restart recovered the surviving SNI bridge", flush=True)

                # Claim names first, export later: event-driven scanning must
                # retry instead of treating the first failed probe as final.
                second = exporter(2, 1.5)
                wait_for(lambda: status().get("pending") == 1, "Late item did not trigger a recovery scan")
                wait_for(lambda: len(registered()) == 2 and status().get("recoveredCount") == 2,
                         "Delayed object export was not retried")
                assert not status()["error"]
                stop(second)
                wait_for(lambda: len(registered()) == 1, "Exited item was left registered")
                print("Name-owner signals, delayed export retries and item removal passed", flush=True)
            finally:
                for process in reversed(processes):
                    stop(process)
                log.seek(0)
                output = log.read()
                if re.search(r"TypeError|ReferenceError|ERROR:|Cannot read property|is not a function", output):
                    raise AssertionError(output[-6000:])


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--export-item":
        export_item(int(sys.argv[2]), float(sys.argv[3]))
    elif "--session" in sys.argv:
        session()
    else:
        subprocess.run(["dbus-run-session", "--", sys.executable, str(Path(__file__).resolve()),
                        "--session"], check=True, timeout=35)


if __name__ == "__main__":
    main()
