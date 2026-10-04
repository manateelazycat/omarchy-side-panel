# Omarchy Side Panel

简体中文 | [English](README.md)

Omarchy 自动隐藏侧边任务栏，支持多显示器。

## 功能

- 鼠标在屏幕左右边缘停留 500 毫秒即可展开；跨屏时先收起当前任务栏，再展开另一条。
- 统一黑白灰图标，悬停时平滑放大。
- 按点击次数排序，重启后保留统计；电源菜单始终排在第一位。
- 图标超出高度时支持滚轮滑动和弹性回弹；**Alt + 滚轮**保留图标原有操作。
- 复用现有右侧插件和应用托盘图标。
- 提供电源、录屏、空闲锁屏、通知和重启 Shell 按钮。

## 安装

需要支持自定义任务栏插件的 Omarchy（Quickshell）环境。

```sh
git clone https://github.com/manateelazycat/omarchy-side-panel.git
cd omarchy-side-panel
python3 install.py
```

安装器会备份配置并重启 Shell。备份和点击统计保存在 `~/.local/state/omarchy-side-panel/`。

## 配置

在 `~/.config/omarchy/shell.json` 的 `bar.sidePanel` 中调整：

```json
{
  "iconSize": 28,
  "showDelay": 500,
  "magnification": 1.28
}
```

图标大小单位为像素，展开延迟单位为毫秒；保存后生效。

## 恢复或卸载

恢复之前使用的任务栏：

```sh
python3 install.py restore
```

卸载并恢复之前的任务栏：

```sh
python3 install.py uninstall
```

## 许可证

[GPL-3.0-only](LICENSE)。
