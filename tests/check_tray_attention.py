"""Check real frame detection, shared click dismissal and rendered dot colors."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def pixels(path):
    return subprocess.check_output(["magick", str(path), "-depth", "8", "rgba:-"])


def main():
    source = Path(__file__).resolve().parents[1]
    omarchy = Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy"))
    with tempfile.TemporaryDirectory(prefix="side-panel-tray-attention-") as directory:
        root = Path(directory)
        for name in ("Commons", "Ui"):
            (root / name).symlink_to(omarchy / "shell" / name, target_is_directory=True)
        shutil.copytree(source / "Ui", root / "Plugin/Ui")
        shutil.copytree(source / "Icons", root / "Plugin/Icons")
        for name in ("TrayButton.qml", "TrayAttention.qml", "TrayIconModel.js", "UsageModel.js"):
            shutil.copy2(source / name, root / "Plugin" / name)
        for package in (root / "Plugin", root / "Plugin/Ui"):
            with (package / "qmldir").open("a") as stream:
                for path in package.glob("*.qml"):
                    if path.stem != "PopupAppearance":
                        stream.write(f"{path.stem} 1.0 {path.name}\n")
        shutil.copy2(source / "tests/qml/tray-attention.qml", root / "shell.qml")
        (root / "normal.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><rect width="32" height="32" fill="#138a33"/></svg>')
        (root / "blank.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"/>')
        environment = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "rhi",
                       "QSG_RHI_BACKEND": "opengl", "QT_QPA_PLATFORMTHEME": "", "QT_ACCESSIBILITY": "0",
                       "NO_AT_BRIDGE": "1", "GIO_USE_VFS": "local", "QT_LOGGING_RULES": "",
                       "QS_DISABLE_FILE_WATCHER": "1", "TRAY_PREVIEW_DIR": str(root)}
        result = subprocess.run(["quickshell", "-p", str(root), "--no-color"], env=environment,
                                capture_output=True, text=True, timeout=20)
        output = result.stdout + result.stderr
        if result.returncode or "TRAY_ATTENTION_PASS" not in output or re.search(
                r"TRAY_ATTENTION_FAIL|TRAY_ATTENTION_TIMEOUT|TypeError|ReferenceError|ERROR:|Cannot read property", output):
            raise SystemExit(f"Tray attention integration failed ({result.returncode})\n{output[-6000:]}")
        normal = pixels(root / "normal.png")
        alert = pixels(root / "alert.png")
        cleared = pixels(root / "cleared.png")
        themed = pixels(root / "theme.png")
        assert normal == cleared, "Acknowledgement changed the stable monogram"
        # Inspect paint, not just the QML properties: the outlined icon must
        # have a visible letter and transparent space inside its border.
        transparent_pixels = 0
        letter_pixels = 0
        for y in range(26, 86):
            for x in range(26, 86):
                offset = (y * 112 + x) * 4
                r, g, b, alpha = normal[offset:offset+4]
                if alpha <= 5:
                    transparent_pixels += 1
                if 36 <= x <= 76 and 36 <= y <= 76 and alpha >= 250 and min(r,g,b) >= 219:
                    letter_pixels += 1
        solid = [normal[i:i+3] for i in range(0, len(normal), 4) if normal[i+3] >= 250]
        assert solid and all(max(abs(v-221) for v in color) <= 1 for color in solid), "WeChat does not share the other icons' tint"
        assert transparent_pixels > 1200 and letter_pixels > 100, "Transparent outline or painted W is missing"
        for name in ("lazycat", "flclash"):
            artwork = pixels(root / (name + ".png"))
            solid = [artwork[i:i+3] for i in range(0, len(artwork), 4) if artwork[i+3] >= 250]
            assert solid, f"Customized {name} artwork is blank"
            assert not any(max(abs(v-102) for v in color) <= 1 for color in solid), f"Customized {name} artwork became a gray tile"
        changed = []
        for index in range(0, len(normal), 4):
            if normal[index:index+4] != alert[index:index+4]:
                changed.append((index // 4 % 112, index // 4 // 112))
        assert changed and all(x >= 66 and y <= 42 for x, y in changed), "Blink changed pixels outside the upper-right dot"
        # Check the dot's center. Its theme color must not be desaturated by
        # the old tray-wide grayscale shader.
        offset = (32 * 112 + 80) * 4
        assert alert[offset:offset+3] == bytes.fromhex("7aa2f7"), "Dot did not use the current theme color"
        assert themed[offset:offset+3] == bytes.fromhex("ff9944"), "Dot did not follow a theme change"
        assert all(alert[i:i+4] == themed[i:i+4] for i in range(0, len(alert), 4)
                   if not (i // 4 % 112 >= 66 and i // 4 // 112 <= 42)), "Accent change recolored the outline or W"
        print("Native blink detection, outlined W, custom icons, independent theme accent, automatic clearing and shared click dismissal passed")


if __name__ == "__main__":
    main()
