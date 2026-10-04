"""Test real edge hover delivery without taking input or moving the user's cursor."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    source = Path(__file__).resolve().parents[1]
    omarchy = Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy"))
    with tempfile.TemporaryDirectory(prefix="side-panel-edges-") as directory:
        root = Path(directory)
        plugin = root / "Plugin"
        plugin.mkdir()
        (root / "Commons").symlink_to(omarchy / "shell/Commons", target_is_directory=True)
        shutil.copytree(omarchy / "shell/Ui", root / "Ui")
        # Exercise the real native anchoring handler without grabbing focus,
        # drawing a popup, or intercepting the user's pointer.
        popup = root / "Ui/PopupCard.qml"
        native = popup.read_text().replace("id: root\n", "id: root\n  mask: Region {}\n", 1)
        native = native.replace('active: root.open && root.triggerMode === "click"', "active: false")
        native = native.replace("opacity: root.open ? 1.0 : 0", "opacity: 0")
        popup.write_text(native)
        for path in (*source.glob("*.qml"), *source.glob("*.js")):
            shutil.copy2(path, plugin / path.name)
        for name in ("Ui", "Icons"):
            shutil.copytree(source / name, plugin / name)

        # Keep the actual PanelWindow/Item/HoverHandler hierarchy and all its
        # dwell/reparent/animation logic. Only isolate compositor input and
        # painting: these windows never intercept the user's real pointer.
        path = plugin / "DockSurface.qml"
        text = path.read_text().replace('id: rightWindow', 'id: rightWindow\n        objectName: "rightEdgeWindow"')
        text = text.replace("WlrLayer.Top", "WlrLayer.Background")
        text = text.replace('"omarchy-side-panel"', '"side-panel-edge-test-left"')
        text = text.replace('"omarchy-side-panel-right"', '"side-panel-edge-test-right"')
        text = text.replace("surface.host.barHidden ? 0 : surface.host.options.triggerWidth", "0")
        for side in ("!surface.onRight", "surface.onRight"):
            text = text.replace(f"surface.shown && {side} ? surface.dockWidth + surface.host.options.hideDistance : 0", "0")
        text = text.replace("id: scene\n", "id: scene\n        opacity: 0\n")
        text = text.replace("id: powerPopup\n", 'id: powerPopup\n        objectName: "powerPopup"\n        mask: Region {}\n')
        text = text.replace("id: powerCapsule\n", "id: powerCapsule\n            opacity: 0\n")
        text = text.replace("active: powerPopup.open", "active: false")
        # Five real action cells exceed this viewport by 22px, matching the
        # current desktop overflow without loading any user's plugin services.
        text = text.replace("Math.max(100, height - 80)", "244")
        path.write_text(text)
        for package in (plugin, plugin / "Ui"):
            with (package / "qmldir").open("a") as stream:
                for path in package.glob("*.qml"):
                    if path.stem != "PopupAppearance":
                        stream.write(f"{path.stem} 1.0 {path.name}\n")
        shutil.copy2(source / "tests/qml/dock-edges.qml", root / "shell.qml")
        environment = {**os.environ, "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software",
                       "QT_LOGGING_RULES": "", "QS_DISABLE_FILE_WATCHER": "1",
                       "XDG_CACHE_HOME": str(root / "cache")}
        result = subprocess.run(["quickshell", "-p", str(root), "--no-color"],
                                capture_output=True, text=True, timeout=40, env=environment)
        output = result.stdout + result.stderr
        if result.returncode or "EDGES_PASS" not in output or re.search(
                r"EDGES_FAIL|TypeError|ReferenceError|ERROR:|Cannot read property|is not a function", output):
            raise SystemExit(f"edge hover integration failed ({result.returncode})\n{output[-6000:]}")
        print(next(line.split("EDGES_PASS", 1)[1].strip() for line in output.splitlines() if "EDGES_PASS" in line))


if __name__ == "__main__":
    main()
