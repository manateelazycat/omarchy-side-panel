# Omarchy Side Panel

简体中文 | [English](README.md)

https://github.com/user-attachments/assets/0801ce55-6533-4995-a50d-ac23447fdbd9

Omarchy 自动隐藏侧边任务栏，支持多显示器。

## 功能

- 鼠标在屏幕左右边缘停留 500 毫秒即可展开；跨屏时先收起当前任务栏，再展开另一条。
- 统一黑白灰图标，悬停时平滑放大。
- 按点击次数排序，重启后保留统计；电源菜单固定第一位，当前时间固定第二位，以单色数码管显示小时和分钟。数字按屏幕像素绘制，时间项稍高，便于辨认。
- 图标超出高度时支持滚轮滑动和弹性回弹；**Alt + 滚轮**保留图标原有操作。
- 复用现有右侧插件，内置系统托盘；所有未隐藏的应用图标直接显示，无展开箭头，无需单独安装托盘插件。
- 保留托盘隐藏与固定设置、应用点击和滚轮操作、右键菜单及多级子菜单。
- Shell 重启后自动恢复仍在运行的应用托盘，支持 Catlink 的远程微信托盘。
- 微信托盘使用圆角矩形边框和大写 W，线条与其他图标一致；其他普通托盘使用灰色圆角矩形和大写首字母，保留懒猫微服和 FlClash 的定制图标。闪烁提醒改为跟随主题主色的圆点，提醒结束或点击图标后清除。
- 提供电源、录屏、空闲锁屏、通知和重启 Shell 按钮。

## 安装

需要支持自定义任务栏插件的 Omarchy（Quickshell）环境。

```sh
git clone https://github.com/manateelazycat/omarchy-side-panel.git
cd omarchy-side-panel
python3 install.py
```

安装器会备份配置并重启 Shell。备份和点击统计保存在 `~/.local/state/omarchy-side-panel/`。

安装时会将旧的 `io.github.manateelazycat.tray-bar` 配置迁移到 `omarchy.tray`，保留原有设置。安装完成后，可运行 `omarchy plugin remove io.github.manateelazycat.tray-bar --yes` 卸载旧插件。

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

内置托盘改编自 Omarchy Tray Bar 和 Omarchy，详见[第三方声明](THIRD_PARTY_NOTICES.md)。
