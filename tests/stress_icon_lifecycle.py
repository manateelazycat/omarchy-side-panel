"""Exercise real QML adapters and forced GC in a separate offscreen shell."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-ui", type=Path, help="Also exercise an earlier Ui directory")
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    omarchy = Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy"))
    cases = [("current", source / "Ui")]
    if args.baseline_ui:
        cases.insert(0, ("baseline", args.baseline_ui))
    environment = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
                   "QT_LOGGING_RULES": "", "QS_DISABLE_FILE_WATCHER": "1"}
    for label, ui in cases:
        with tempfile.TemporaryDirectory(prefix="side-panel-lifecycle-") as directory:
            root = Path(directory)
            (root / "Commons").symlink_to(omarchy / "shell/Commons", target_is_directory=True)
            (root / "Ui").symlink_to(omarchy / "shell/Ui", target_is_directory=True)
            shutil.copytree(source / "Ui", root / "Plugin/Ui")
            shutil.copytree(source / "Icons", root / "Plugin/Icons")
            for name in ("IconNormalizer.qml", "IconRasterizer.qml", "PopupStyler.qml"):
                shutil.copy2(ui / name, root / "Plugin/Ui" / name)
            # Register the fixture's private types explicitly; this runner
            # has no host plugin registry to discover the sibling components.
            qmldir = root / "Plugin/Ui/qmldir"
            with qmldir.open("a") as stream:
                for path in (root / "Plugin/Ui").glob("*.qml"):
                    if path.stem != "PopupAppearance":
                        stream.write(f"{path.stem} 1.0 {path.name}\n")
            shutil.copy2(source / "tests/qml/icon-lifecycle.qml", root / "shell.qml")
            result = subprocess.run(["quickshell", "-p", str(root), "--no-color"],
                                    capture_output=True, text=True, timeout=30, env=environment)
            output = result.stdout + result.stderr
            if result.returncode or "LIFECYCLE_PASS 500" not in output or re.search(
                    r"TypeError|ReferenceError|ERROR:|Cannot read property|is not a function", output):
                raise SystemExit(f"{label}: lifecycle stress failed ({result.returncode})\n{output[-6000:]}")
            print(f"{label}: 500 replacement cycles and 1000 forced garbage collections passed", flush=True)


if __name__ == "__main__":
    main()
