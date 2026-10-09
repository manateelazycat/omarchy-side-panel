"""Check native clicks, stable QML sorting, and disk persistence across processes."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    source = Path(__file__).resolve().parents[1]
    omarchy = Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy"))
    with tempfile.TemporaryDirectory(prefix="side-panel-usage-") as directory:
        root = Path(directory)
        (root / "Commons").symlink_to(omarchy / "shell/Commons", target_is_directory=True)
        (root / "Ui").symlink_to(omarchy / "shell/Ui", target_is_directory=True)
        shutil.copytree(source / "Ui", root / "Plugin/Ui")
        shutil.copytree(source / "Icons", root / "Plugin/Icons")
        for name in ("IconUsage.qml", "UsageModel.js", "TrayIconModel.js", "TrayButton.qml", "DockLayout.qml", "ActionIcon.qml", "ClockIcon.qml"):
            shutil.copy2(source / name, root / "Plugin" / name)
        for package in (root / "Plugin", root / "Plugin/Ui"):
            with (package / "qmldir").open("a") as stream:
                for path in package.glob("*.qml"):
                    if path.stem != "PopupAppearance":
                        stream.write(f"{path.stem} 1.0 {path.name}\n")
        shutil.copy2(source / "tests/qml/icon-usage.qml", root / "shell.qml")
        state = root / "state/omarchy-side-panel"
        state.mkdir(parents=True)
        environment = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
                       "QT_LOGGING_RULES": "", "QS_DISABLE_FILE_WATCHER": "1",
                       "XDG_STATE_HOME": str(state.parent)}
        for phase in ("initial", "resume"):
            result = subprocess.run(["quickshell", "-p", str(root), "--no-color"],
                                    capture_output=True, text=True, timeout=20,
                                    env={**environment, "USAGE_PHASE": phase})
            output = result.stdout + result.stderr
            if result.returncode or f"USAGE_PASS {phase}" not in output or re.search(
                    r"USAGE_FAIL|TypeError|ReferenceError|ERROR:|Cannot read property|is not a function", output):
                raise SystemExit(f"{phase}: usage integration failed ({result.returncode})\n{output[-6000:]}")
            data = json.loads((state / "click-counts.json").read_text())
            assert data["version"] == 1
            assert data["counts"]["widget:test"] == (3 if phase == "initial" else 4)
            assert data["counts"]["tray:lzc-client-desktop_status_icon"] == 3
            assert data["counts"]["action:reload"] == 1
            print(f"{phase}: native clicks, stable positions, and durable counts passed", flush=True)


if __name__ == "__main__":
    main()
