"""Render the real icon adapters, checking size, centering, tint and states."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile


def inspect(path, contrast=False):
    width, height = struct.unpack('>II', path.read_bytes()[16:24])
    pixels = subprocess.check_output(['magick', str(path), '-depth', '8', 'rgba:-'])
    assert len(pixels) == width * height * 4
    points = []
    solid = []
    for i in range(width * height):
        r, g, b, a = pixels[i*4:i*4+4]
        if a >= 32:
            points.append((i % width, i // width))
        if a >= 250:
            solid.append((r, g, b))
    assert points and solid, f'Blank icon: {path.name}'
    left = min(x for x, _ in points)
    right = max(x for x, _ in points) + 1
    top = min(y for _, y in points)
    bottom = max(y for _, y in points) + 1
    if contrast:
        assert all(max(color)-min(color) <= 1 for color in solid), f'Tray is colored: {path.name}'
        assert max(max(color) for color in solid) >= 219, f'Tray foreground differs: {path.name}'
        assert min(min(color) for color in solid) <= 20, f'Tray detail disappeared: {path.name}'
    else:
        assert all(max(abs(v-221) for v in color) <= 1 for color in solid), f'Tint differs: {path.name}'
    assert abs((left+right)/2 - width/2) <= 2, f'Horizontal alignment: {path.name}'
    assert abs((top+bottom)/2 - height/2) <= 2, f'Vertical alignment: {path.name}'
    return max(right-left, bottom-top)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--staged', type=Path, help='Validate staged icon changes before applying them')
    staged = parser.parse_args().staged
    source = Path(__file__).resolve().parents[1]
    omarchy = Path(os.environ.get('OMARCHY_PATH', '/usr/share/omarchy'))
    projects = source.parent
    with tempfile.TemporaryDirectory(prefix='side-panel-icon-style-') as directory:
        root = Path(directory)
        for name in ('Commons', 'Ui'):
            (root/name).symlink_to(omarchy/'shell'/name, target_is_directory=True)
        for name in ('Ui', 'Icons'):
            shutil.copytree(source/name, root/'Plugin'/name)
            if staged:
                shutil.copytree(staged/source.name/name, root/'Plugin'/name, dirs_exist_ok=True)
        for name in ('ActionIcon.qml', 'TrayButton.qml', 'UsageModel.js'):
            path = staged/source.name/name if staged and (staged/source.name/name).exists() else source/name
            shutil.copy2(path, root/'Plugin'/name)
        for package in (root/'Plugin', root/'Plugin/Ui'):
            with (package/'qmldir').open('a') as stream:
                for path in package.glob('*.qml'):
                    if path.stem != 'PopupAppearance':
                        stream.write(f'{path.stem} 1.0 {path.name}\n')
        records = [{'name': '日历', 'url': str(projects/'omarchy-days/CalendarIcon.qml')}]
        for project, icon in [
            ('omarchy-color-picker', 'ColorPickerIcon'),
            ('omarchy-language-switcher', 'LanguageIcon'),
            ('omarchy-startup-map', 'RocketIcon'),
            ('omarchy-power-awake', 'PowerAwakeIcon'),
            ('omarchy-fctix-status', 'FcitxIcon'),
            ('omarchy-workspace-gallery', 'GalleryIcon'),
        ]:
            path = (staged if staged else projects)/project/(icon+'.qml')
            records.append({'name': icon, 'url': str(path)})
        (root/'records.json').write_text(json.dumps(records, ensure_ascii=False))
        (root/'generic-tray.svg').write_text(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
            '<rect width="24" height="24" fill="#238b32"/>'
            '<circle cx="12" cy="12" r="8" fill="white"/>'
            '<circle cx="12" cy="12" r="3" fill="black"/></svg>')
        (root/'cache/omarchy-side-panel/icons').mkdir(parents=True)
        shutil.copy2(source/'tests/qml/icon-style.qml', root/'shell.qml')
        environment = {**os.environ, 'QT_QPA_PLATFORM': 'offscreen', 'QT_QUICK_BACKEND': 'rhi',
                       'QSG_RHI_BACKEND': 'opengl', 'QS_DISABLE_FILE_WATCHER': '1',
                       'QT_LOGGING_RULES': '', 'ICON_PREVIEW_DIR': str(root),
                       'XDG_CACHE_HOME': str(root/'cache')}
        result = subprocess.run(['quickshell', '-p', str(root), '--no-color'],
                                env=environment, capture_output=True, text=True, timeout=20)
        output = result.stdout + result.stderr
        if result.returncode or 'ICON_PASS' not in output or re.search(
                r'ICON_FAIL|ICON_TIMEOUT|TypeError|ReferenceError|ERROR:|Cannot read property', output):
            raise SystemExit(f'Icon rendering failed ({result.returncode})\n{output[-7000:]}')
        for phase in range(3):
            paths = [root/f'{index}-{phase}.png' for index in range(19)]
            extents = [inspect(path, contrast=index == 18) for index, path in enumerate(paths)]
            expected = 64 * (1.28 if phase == 2 else 1)
            assert all(abs(extent-expected) <= 2 for extent in extents), (phase, extents)
        print('19 icons: calendar sizing, shared tint, tray contrast, state changes and hover magnification passed')


if __name__ == '__main__':
    main()
