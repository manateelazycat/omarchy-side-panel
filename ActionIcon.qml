import QtQuick
import QtQuick.Window
import qs.Commons
import qs.Ui
import "Ui" as PanelUi

BarIconButton {
    id: root
    required property var host
    required property string action
    bar: host
    fixedWidth: host.barSize
    fixedHeight: Style.bar.iconSlot
    opticalSize: Style.bar.iconCanvas
    fontSize: Style.bar.iconFont
    fontFamily: action === "power" ? "omarchy" : host.fontFamily
    layer.enabled: true
    layer.textureSize: host.options.pixelated
        ? Qt.size(Math.max(1, Math.round(width * host.options.iconPixels / opticalSize)),
            Math.max(1, Math.round(height * host.options.iconPixels / opticalSize)))
        : Qt.size(Math.ceil(width * Screen.devicePixelRatio * 4), Math.ceil(height * Screen.devicePixelRatio * 4))
    layer.smooth: !host.options.pixelated
    layer.mipmap: false
    layer.effect: PanelUi.MonochromeIconEffect { smooth: !root.host.options.pixelated; ink: root.host.foreground }
    layer.sourceRect: iconNormalizer.sourceRect
    readonly property var iconNormalizer: PanelUi.IconNormalizer {
        parent: root
        sourceItem: root
        targetSize: root.opticalSize
    }
    readonly property var iconRasterizer: PanelUi.IconRasterizer {
        parent: root
        rootItem: root
        glyphFiles: root.action === "power" ? ({"\ue900": "widgets/power.svg"})
            : root.action === "recording" ? ({"󰻂": "widgets/recording.svg", "󰓛": "widgets/recording-stop.svg"})
            : root.action === "idle" ? ({"󰅶": "widgets/idle.svg", "󰒲": "widgets/idle-blocked.svg"})
            : root.action === "notifications" ? ({"󰂛": "widgets/notifications.svg", "󰂚": "widgets/notifications-silent.svg"})
            : root.action === "reload" ? ({"󰑐": "widgets/reload.svg"}) : ({})
        pixelated: root.host.options.pixelated
        pixels: root.host.options.iconPixels
    }
    text: action === "power" ? "\ue900"
        : action === "recording" ? (host.recording ? "󰓛" : "󰻂")
        : action === "idle" ? (host.stayAwake ? "󰅶" : "󰒲")
        : action === "reload" ? "󰑐"
        : (host.doNotDisturb ? "󰂛" : "󰂚")
    active: action === "recording" ? host.recording
        : action === "idle" ? host.stayAwake : action === "notifications" && host.doNotDisturb
    tooltipText: action === "power" ? "电源"
        : action === "recording" ? (host.recording ? "停止录屏" : "屏幕录制")
        : action === "idle" ? (host.stayAwake ? "Allow Idle Lock & Screensaver" : "Stay Awake")
        : action === "reload" ? "重载 Shell"
        : (host.doNotDisturb ? "Allow Notifications" : "Silence Notifications")
    onPressed: function(button) {
        if (button !== Qt.LeftButton) return;
        host.recordIconClick("action:" + action);
        if (action === "power") return;
        if (action === "recording") host.toggleRecording();
        else if (action === "idle") host.toggleIdle();
        else if (action === "notifications") host.toggleNotifications();
        else if (action === "reload") host.reloadShell();
    }
}
