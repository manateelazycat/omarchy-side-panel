"""Render the capsule and intercept every power action during real mouse input."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview-dir", type=Path)
    preview = parser.parse_args().preview_dir
    source = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="side-panel-power-") as directory:
        root = Path(directory)
        (root / "Plugin/Ui").mkdir(parents=True)
        for name in ("PowerCapsule.qml", "PopupAppearance.qml", "qmldir"):
            shutil.copy2(source / "Ui" / name, root / "Plugin/Ui" / name)
        omarchy = Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy"))
        (root / "Commons").symlink_to(omarchy / "shell/Commons", target_is_directory=True)
        (root / "Ui").symlink_to(omarchy / "shell/Ui", target_is_directory=True)
        shutil.copytree(source / "Icons/menu", root / "Plugin/Icons/menu")
        (root / "shell.qml").write_text((source / "tests/qml/power-capsule.qml").read_text().replace('"Ui" as PanelUi', '"Plugin/Ui" as PanelUi'))
        images = preview if preview else root / "images"
        images.mkdir(parents=True, exist_ok=True)
        environment = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "rhi",
                       "QSG_RHI_BACKEND": "opengl", "QT_LOGGING_RULES": "",
                       "QS_DISABLE_FILE_WATCHER": "1", "POWER_PREVIEW_DIR": str(images),
                       "XDG_CACHE_HOME": str(root / "cache")}
        result = subprocess.run(["quickshell", "-p", str(root), "--no-color"],
                                capture_output=True, text=True, timeout=20, env=environment)
        output = result.stdout + result.stderr
        if result.returncode or "CAPSULE_PASS" not in output or re.search(
                r"CAPSULE_FAIL|TypeError|ReferenceError|ERROR:|Cannot read property|is not a function", output):
            raise SystemExit(f"Power capsule failed ({result.returncode})\n{output[-6000:]}")
        print("Both opening directions, staggered entry, hover, press, all intercepted actions and rapid reopen passed")
        if preview:
            print(f"Rendered previews: {images}")


if __name__ == "__main__":
    main()
