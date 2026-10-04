# Omarchy Side Panel

Omarchy 的左侧居中任务栏插件。默认隐藏，鼠标在屏幕左侧正中间上下各 60 像素的边缘区域连续停留 500 毫秒后滑出，快速路过不会展开。提前离开触发区域会取消计时，再次进入时重新计时。展开后可操作整条任务栏，离开任务栏周围的缓冲区域后收回。图标悬停时平滑放大。

从上到下：电源按钮、原任务栏右侧整组图标、录屏／停止录屏、空闲锁屏开关、通知开关。点击电源按钮，在右侧弹出关机、注销、重启三个操作。原有 `hyprmoncfg` 图标存在时排除 `omarchy.monitor`。

图标默认使用 16×16 光学画布对应的像素网格和最近邻放大，呈现类似《我的世界》物品图标的方块边缘，悬停放大时仍保留像素感。全部任务栏图标统一显示为黑白灰，包括应用托盘图标和选中状态；保留原有图案、透明度和明暗层次。托盘图标从原来的 12 像素画布增大到 16 像素画布。Tooltip、弹出菜单及任务栏背景沿用原有圆角样式。

悬停任意图标约 350 毫秒后，在任务栏右侧显示 Tooltip，移开后消失。托盘应用和插件保留原有提示，未提供提示文字的图标使用功能名称；打开面板后仍可查看任务栏图标的提示。

左键或右键打开的任务栏菜单共用 Tooltip 的外观：8 像素圆角、1 像素边框、同一背景、文字颜色及 12 像素字体。样式随主题更新，保留菜单按钮、键盘操作和子菜单。语言切换、显示器重载、登录启动应用的独立面板也使用同一适配器；安装器会备份这三个用户插件的 `Service.qml`，恢复默认栏或卸载时移除插入的适配代码。第三方应用自行绘制的窗口由应用管理。

安装前自动备份 `shell.json`，通过 Omarchy 的完整任务栏接口替换默认栏。原有左右中间布局保留在配置中，不修改系统安装目录。每块屏幕都有独立的左侧任务栏；高度超出屏幕时可滚动。安装或更新时会通过 `omarchy restart shell` 重载完整入口，并检查插件是否成功启动。

## 安装

```sh
python3 install.py
```

## 恢复默认任务栏

```sh
python3 install.py restore
```

恢复安装前使用的任务栏，保留安装后的图标配置变化。卸载并恢复：

```sh
python3 install.py uninstall
```

备份位于 `~/.local/state/omarchy-side-panel/`。再次启用可运行 `omarchy plugin enable andy.side-panel`。

## 外观参数

可在 `~/.config/omarchy/shell.json` 的 `bar` 下加入 `sidePanel`，保存后自动生效：

```json
"sidePanel": {
  "iconSize": 28,
  "pixelated": true,
  "iconPixels": 16,
  "magnification": 1.28,
  "triggerWidth": 2,
  "triggerHeight": 120,
  "showDelay": 500,
  "hideDistance": 24,
  "hideDelay": 260,
  "animationDuration": 300
}
```

尺寸单位为逻辑像素，时间单位为毫秒。`iconSize` 为显示的图标画布大小。`iconPixels` 为像素网格精度（8–24），越小方块越明显；`pixelated: false` 恢复平滑图标，图标仍保持黑白灰。`triggerHeight` 为左侧居中触发区域的高度，`showDelay` 为展开前需连续停留的时间。任务栏采用浮层，不预留窗口空间；面板打开期间保持显示，点击外部关闭面板后恢复自动隐藏。

内置图标和第三方图标直接使用当前 Omarchy 的组件及主题。语言切换、显示器重新加载、登录启动应用、Power Awake 使用各插件已有的 IPC，适配完整任务栏不提供第三方私有服务对象的接口约定。

## 验证与诊断

```sh
node --test tests/model.test.cjs
omarchy-shell andy.side-panel status
```

需要支持 `kinds: ["bar"]` 的 Omarchy Quickshell 版本。插件依赖系统提供的 `qs.Commons`、`qs.Ui` 和图标字体。

灰度着色器的源码和预编译文件位于 `Ui/`；安装时直接使用预编译文件。修改着色器后可用 Qt 的工具重新生成：

```sh
/usr/lib/qt6/bin/qsb --glsl "100es,120,150" --qsbversion 64 -o Ui/monochrome.frag.qsb Ui/monochrome.frag
```

## 许可证

Copyright (C) 2026 Andy.

本项目的全部源码、文档、测试及随项目提供的预编译着色器均按 GNU General Public License 第 3 版（`GPL-3.0-only`）发布。许可证完整条款见 [LICENSE](LICENSE)。
