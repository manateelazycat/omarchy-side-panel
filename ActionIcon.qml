import QtQuick
import QtQuick.Window
import qs.Ui
import "Ui" as PanelUi

BarIconButton {
    id: root
    required property var host
    required property string action
    bar: host
    fixedWidth: host.barSize
    fixedHeight: 27
    opticalSize: 16
    fontSize: 15
    fontFamily: action === "power" ? "omarchy" : host.fontFamily
    layer.enabled: true
    layer.textureSize: host.options.pixelated
        ? Qt.size(Math.max(1, Math.round(width * host.options.iconPixels / opticalSize)),
            Math.max(1, Math.round(height * host.options.iconPixels / opticalSize)))
        : Qt.size(Math.ceil(width * Screen.devicePixelRatio * 4), Math.ceil(height * Screen.devicePixelRatio * 4))
    layer.smooth: !host.options.pixelated
    layer.mipmap: false
    layer.effect: PanelUi.MonochromeIconEffect { smooth: !root.host.options.pixelated }
    layer.sourceRect: iconNormalizer.sourceRect
    readonly property var iconNormalizer: PanelUi.IconNormalizer {
        parent: root
        sourceItem: root
        targetSize: root.opticalSize
    }
    readonly property var iconRasterizer: PanelUi.IconRasterizer {
        parent: root
        rootItem: root
        pixelated: root.host.options.pixelated
        pixels: root.host.options.iconPixels
    }
    text: action === "power" ? "\ue900"
        : action === "recording" ? (host.recording ? "󰓛" : "󰻂")
        : action === "idle" ? (host.stayAwake ? "󰅶" : "󰒲")
        : (host.doNotDisturb ? "󰂛" : "󰂚")
    active: action === "recording" ? host.recording
        : action === "idle" ? host.stayAwake : action === "notifications" && host.doNotDisturb
    tooltipText: action === "power" ? "电源"
        : action === "recording" ? (host.recording ? "停止录屏" : "屏幕录制")
        : action === "idle" ? (host.stayAwake ? "Allow Idle Lock & Screensaver" : "Stay Awake")
        : (host.doNotDisturb ? "Allow Notifications" : "Silence Notifications")
    onPressed: function(button) {
        if (button !== Qt.LeftButton || action === "power") return;
        if (action === "recording") host.toggleRecording();
        else if (action === "idle") host.toggleIdle();
        else host.toggleNotifications();
    }
}
