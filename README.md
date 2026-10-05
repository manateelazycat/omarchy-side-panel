# Omarchy Side Panel

English | [简体中文](README.zh-CN.md)

https://github.com/user-attachments/assets/0801ce55-6533-4995-a50d-ac23447fdbd9

An auto-hiding side dock for Omarchy, with support for multiple monitors.

## Features

- Hover at either screen edge for 500 ms to reveal the dock. Moving to another screen hides the current dock before opening the next.
- Consistent monochrome icons with hover magnification.
- Icons sort by click count, saved across restarts. The power menu always stays first.
- Scroll overflowing icons with smooth motion and elastic rebound. Hold **Alt** while scrolling to use an icon's original wheel action.
- Uses existing right-side widgets and includes its own system tray, with all non-hidden app icons shown directly and no expander arrow. No separate tray plugin is required.
- Preserves tray hiding and pin settings, app actions, scrolling, context menus and nested submenus.
- Automatically restores live tray items after Shell restarts, including Catlink's remote WeChat tray.
- WeChat uses a rounded outline and uppercase W matching the other icons' strokes; other ordinary tray icons use gray rounded tiles with uppercase initials, preserving the custom LazyCat and FlClash artwork. Blinking becomes a dot that follows the theme accent and clears when attention ends or the icon is clicked.
- Includes power, recording, idle, notification and Shell restart controls.

## Install

Requires Omarchy with Quickshell and support for custom bar plugins.

```sh
git clone https://github.com/manateelazycat/omarchy-side-panel.git
cd omarchy-side-panel
python3 install.py
```

The installer backs up your configuration and restarts Shell. Backups and click counts are stored in `~/.local/state/omarchy-side-panel/`.

Existing `io.github.manateelazycat.tray-bar` entries are migrated to `omarchy.tray`, preserving their settings. After installation, the old plugin can be removed with `omarchy plugin remove io.github.manateelazycat.tray-bar --yes`.

## Configuration

Adjust `bar.sidePanel` in `~/.config/omarchy/shell.json`:

```json
{
  "iconSize": 28,
  "showDelay": 500,
  "magnification": 1.28
}
```

Icon size is in pixels; reveal delay is in milliseconds. Changes apply when saved.

## Restore or uninstall

Restore the previous bar:

```sh
python3 install.py restore
```

Uninstall and restore the previous bar:

```sh
python3 install.py uninstall
```

## License

[GPL-3.0-only](LICENSE).

The integrated tray is adapted from Omarchy Tray Bar and Omarchy. See [third-party notices](THIRD_PARTY_NOTICES.md).
