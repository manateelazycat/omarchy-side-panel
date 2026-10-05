"""Load the internal tray without a plugin registry and exercise native DBus menus."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

from check_tray_recovery import stop, wait_for

SOURCE = Path(__file__).resolve().parents[1]


def export_menu():
    from gi.repository import Gio, GLib

    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    name = f"org.kde.StatusNotifierItem-{os.getpid()}-1"
    bus.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                  "RequestName", GLib.Variant("(su)", (name, 4)), None,
                  Gio.DBusCallFlags.NONE, 2000, None)
    properties = {
        "Id": ("s", "internal-tray-test"), "Title": ("s", "Internal tray test"),
        "Category": ("s", "ApplicationStatus"), "Status": ("s", "Active"),
        "WindowId": ("i", 0), "IconName": ("s", "application-x-executable"),
        "IconPixmap": ("a(iiay)", []), "IconThemePath": ("s", ""),
        "OverlayIconName": ("s", ""), "OverlayIconPixmap": ("a(iiay)", []),
        "AttentionIconName": ("s", ""), "AttentionIconPixmap": ("a(iiay)", []),
        "AttentionMovieName": ("s", ""), "ItemIsMenu": ("b", False), "Menu": ("o", "/Menu"),
        "ToolTip": ("(sa(iiay)ss)", ("", [], "Internal tray test", "")),
    }
    xml = '<node><interface name="org.kde.StatusNotifierItem">' + "".join(
        f'<property name="{key}" type="{signature}" access="read"/>'
        for key, (signature, _) in properties.items()) + "</interface></node>"
    bus.register_object("/StatusNotifierItem", Gio.DBusNodeInfo.new_for_xml(xml).interfaces[0],
                        None, lambda _, __, ___, ____, key: GLib.Variant(*properties[key]), None)

    def node(index, label, children=()):
        props = {"label": GLib.Variant("s", label), "enabled": GLib.Variant("b", True),
                 "visible": GLib.Variant("b", True)}
        if children:
            props["children-display"] = GLib.Variant("s", "submenu")
        return index, props, [GLib.Variant("(ia{sv}av)", child) for child in children]

    nodes = {3: node(3, "Action")}
    nodes[2] = node(2, "Deep", [nodes[3]])
    nodes[1] = node(1, "Nested", [nodes[2]])
    nodes[0] = node(0, "", [nodes[1]])
    xml = '''<node><interface name="com.canonical.dbusmenu">
      <property name="Version" type="u" access="read"/>
      <property name="TextDirection" type="s" access="read"/>
      <property name="Status" type="s" access="read"/>
      <property name="IconThemePath" type="as" access="read"/>
      <method name="GetLayout"><arg type="i" direction="in"/><arg type="i" direction="in"/>
        <arg type="as" direction="in"/><arg type="u" direction="out"/>
        <arg type="(ia{sv}av)" direction="out"/></method>
      <method name="GetGroupProperties"><arg type="ai" direction="in"/>
        <arg type="as" direction="in"/><arg type="a(ia{sv})" direction="out"/></method>
      <method name="AboutToShow"><arg type="i" direction="in"/><arg type="b" direction="out"/></method>
      <method name="Event"><arg type="i" direction="in"/><arg type="s" direction="in"/>
        <arg type="v" direction="in"/><arg type="u" direction="in"/></method>
    </interface></node>'''

    def call(_, __, ___, ____, method, parameters, invocation):
        args = parameters.unpack()
        if method == "GetLayout":
            result = GLib.Variant("(u(ia{sv}av))", (1, nodes[args[0]]))
        elif method == "GetGroupProperties":
            result = GLib.Variant("(a(ia{sv}))", ([(i, nodes[i][1]) for i in args[0] or nodes],))
        elif method == "AboutToShow":
            result = GLib.Variant("(b)", (False,))
        elif method == "Event":
            print(f"MENU_EVENT {args[0]} {args[1]}", flush=True)
            result = None
        else:
            invocation.return_dbus_error("org.freedesktop.DBus.Error.UnknownMethod", method)
            return
        invocation.return_value(result)

    menu_properties = {"Version": ("u", 3), "TextDirection": ("s", "ltr"),
                       "Status": ("s", "normal"), "IconThemePath": ("as", [])}
    bus.register_object("/Menu", Gio.DBusNodeInfo.new_for_xml(xml).interfaces[0], call,
                        lambda _, __, ___, ____, key: GLib.Variant(*menu_properties[key]), None)

    def register():
        try:
            bus.call_sync("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher",
                          "org.kde.StatusNotifierWatcher", "RegisterStatusNotifierItem",
                          GLib.Variant("(s)", (name,)), None, Gio.DBusCallFlags.NONE, 500, None)
            return False
        except GLib.Error:
            return True

    print("EXPORTED", flush=True)
    GLib.timeout_add(100, register)
    GLib.MainLoop().run()


def session():
    omarchy = Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy"))
    with tempfile.TemporaryDirectory(prefix="side-panel-internal-tray-") as directory:
        root = Path(directory)
        (root / "Commons").symlink_to(omarchy / "shell/Commons", target_is_directory=True)
        shutil.copytree(omarchy / "shell/Ui", root / "Ui")
        popup = root / "Ui/PopupCard.qml"
        popup.write_text(popup.read_text().replace('active: root.open && root.triggerMode === "click"', 'active: false'))
        plugin = root / "Plugin"
        plugin.mkdir()
        for path in (*SOURCE.glob("*.qml"), *SOURCE.glob("*.js")):
            shutil.copy2(path, plugin / path.name)
        for name in ("Ui", "Icons"):
            shutil.copytree(SOURCE / name, plugin / name)
        for package in (plugin, plugin / "Ui"):
            with (package / "qmldir").open("a") as stream:
                for path in package.glob("*.qml"):
                    if path.stem != "PopupAppearance":
                        stream.write(f"{path.stem} 1.0 {path.name}\n")
        shutil.copy2(SOURCE / "tests/qml/tray-integration.qml", root / "shell.qml")
        environment = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
                       "QT_QPA_PLATFORMTHEME": "", "QT_ACCESSIBILITY": "0", "NO_AT_BRIDGE": "1",
                       "QT_LOGGING_RULES": "", "GIO_USE_VFS": "local", "QS_DISABLE_FILE_WATCHER": "1"}
        with (root / "menu.log").open("w+") as log:
            exporter = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "--export-menu"],
                                        stdout=log, stderr=log, env=environment)
            try:
                def ready():
                    log.seek(0)
                    return "EXPORTED" in log.read()
                wait_for(ready, "Menu fixture did not start")
                result = subprocess.run(["quickshell", "-p", str(root), "--no-color"], env=environment,
                                        capture_output=True, text=True, timeout=20)
                output = result.stdout + result.stderr
                if result.returncode or "TRAY_INTEGRATION_PASS" not in output or re.search(
                        r"TRAY_INTEGRATION_FAIL|TypeError|ReferenceError|ERROR:|Cannot read property|is not a function", output):
                    log.seek(0)
                    raise AssertionError(output[-8000:] + "\nMenu fixture:\n" + log.read()[-4000:])
                log.seek(0)
                assert "MENU_EVENT 3 clicked" in log.read(), "Leaf selection did not reach the native menu"
            finally:
                stop(exporter)
        print("Internal tray without registry: filtering, settings, two nested native menus and app actions passed")


if __name__ == "__main__":
    if "--export-menu" in sys.argv:
        export_menu()
    elif "--session" in sys.argv:
        session()
    else:
        result = subprocess.run(["dbus-run-session", "--", sys.executable, str(Path(__file__).resolve()),
                                 "--session"], capture_output=True, text=True, timeout=30)
        if result.returncode:
            raise SystemExit(result.stdout + result.stderr[-10000:])
        print(result.stdout.strip())
