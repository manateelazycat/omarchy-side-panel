"""Exercise actual QML dwell/animation sequencing without moving the user's cursor."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    source = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="side-panel-handoff-") as directory:
        root = Path(directory)
        plugin = root / "Plugin"
        plugin.mkdir()
        shutil.copy2(source / "DockCoordinator.qml", plugin / "DockCoordinator.qml")
        (plugin / "qmldir").write_text("DockCoordinator 1.0 DockCoordinator.qml\n")
        shutil.copy2(source / "tests/qml/dock-handoff.qml", root / "shell.qml")
        environment = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
                       "QT_LOGGING_RULES": "", "QS_DISABLE_FILE_WATCHER": "1"}
        result = subprocess.run(["quickshell", "-p", str(root), "--no-color"],
                                capture_output=True, text=True, timeout=20, env=environment)
        output = result.stdout + result.stderr
        if result.returncode or "HANDOFF_PASS A:left,B:right,B:left,C:left" not in output or re.search(
                r"HANDOFF_FAIL|TypeError|ReferenceError|ERROR:|Cannot read property|is not a function", output):
            raise SystemExit(f"handoff integration failed ({result.returncode})\n{output[-6000:]}")
        print("Cross-monitor, same-monitor, rapid target changes and cancelled reveals passed; no animation overlap")


if __name__ == "__main__":
    main()
