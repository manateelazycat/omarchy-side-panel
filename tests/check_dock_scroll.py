"""Exercise wheel routing and elastic scrolling with real Qt wheel events."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    source = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="side-panel-scroll-") as directory:
        root = Path(directory)
        (root / "Ui").mkdir()
        shutil.copy2(source / "Ui/ElasticFlickable.qml", root / "Ui/ElasticFlickable.qml")
        shutil.copy2(source / "tests/qml/dock-scroll.qml", root / "shell.qml")
        environment = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
                       "QT_LOGGING_RULES": "", "QS_DISABLE_FILE_WATCHER": "1"}
        result = subprocess.run(["quickshell", "-p", str(root), "--no-color"],
                                capture_output=True, text=True, timeout=25, env=environment)
        output = result.stdout + result.stderr
        if result.returncode or "SCROLL_PASS" not in output or re.search(
                r"SCROLL_FAIL|TypeError|ReferenceError|ERROR:|Cannot read property|is not a function", output):
            raise SystemExit(f"wheel scrolling failed ({result.returncode})\n{output[-6000:]}")
        print("Wheel priority, smooth motion, both elastic bounds, rapid reversal, icon clicks and native wheel fallback passed")


if __name__ == "__main__":
    main()
