import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons
import "UsageModel.js" as Usage
import "TrayIconModel.js" as TrayModel
import "Ui/TraySvg.js" as TraySvg
import "Ui" as PanelUi

// Individual tray cells share the side panel's internal menu controller.
Item {
    id: button
    required property var host
    required property var controller
    required property var modelData
    readonly property string usageKey: Usage.trayKey(modelData)
    readonly property color foreground: host.foreground
    readonly property string customIconFile: TraySvg.packagedFile(
        [modelData.id, modelData.title, modelData.tooltipTitle].join(" "), "")
    readonly property bool outlined: !customIconFile && /wechat|weixin|微信/i.test(TrayModel.name(modelData) + " " + String(modelData.id || ""))
    readonly property string initial: outlined ? "W" : TrayModel.initial(modelData)
    readonly property var attentionState: "trayAttention" in host ? host.trayAttention.stateFor(modelData) : null
    readonly property bool attention: attentionState ? attentionState.pending : false
    readonly property bool tooltipHovered: visible && mouse.containsMouse
    readonly property var iconNormalizer: PanelUi.IconNormalizer {
        parent: button
        sourceItem: button
        targetSize: Style.bar.iconCanvas
    }
    implicitWidth: host.barSize
    implicitHeight: Style.bar.iconSlot
    width: implicitWidth
    height: implicitHeight
    layer.enabled: true
    layer.sourceRect: iconNormalizer.sourceRect
    layer.smooth: !host.options.pixelated
    layer.textureSize: host.options.pixelated
        ? Qt.size(Math.round(width * host.options.iconPixels / Style.bar.iconCanvas),
            Math.round(height * host.options.iconPixels / Style.bar.iconCanvas))
        : Qt.size(Math.ceil(width * Screen.devicePixelRatio * 4), Math.ceil(height * Screen.devicePixelRatio * 4))
    PanelUi.TrayMonogram {
        id: icon
        anchors.centerIn: parent
        anchors.alignWhenCentered: false
        width: Style.bar.iconCanvas
        height: Style.bar.iconCanvas
        initial: button.initial
        outlined: button.outlined
        customIconSource: button.customIconFile ? Qt.resolvedUrl("Icons/" + button.customIconFile) : ""
        foreground: button.foreground
        attentionColor: Color.accent
        fontFamily: button.host.fontFamily
        attention: button.attention
    }
    // Inspect native frames without painting them into the visible icon.
    Canvas {
        id: probe
        width: 32; height: 32; opacity: 0
        readonly property string iconSource: String(button.modelData.icon || "")
        property string loadedSource: ""
        function refresh() {
            if (!available || !button.attentionState) return;
            if (loadedSource) unloadImage(loadedSource);
            loadedSource = iconSource;
            if (loadedSource) {
                loadImage(loadedSource);
                if (isImageLoaded(loadedSource)) sample();
            }
            else button.attentionState.observeFrame({signature: "blank", blank: true});
        }
        function sample() {
            if (!button.attentionState || !loadedSource || !isImageLoaded(loadedSource)) return;
            var context = getContext("2d");
            context.reset(); context.drawImage(loadedSource, 0, 0, width, height);
            button.attentionState.observeFrame(TrayModel.frame(context.getImageData(0, 0, width, height).data));
        }
        onIconSourceChanged: refresh()
        onAvailableChanged: if (available) refresh()
        onImageLoaded: sample()
    }
    onAttentionStateChanged: probe.refresh()
    function dismissAttention() { if (attentionState) attentionState.acknowledge(); }
    function snapshot() {
        return {name: TrayModel.name(modelData), initial: customIconFile ? "" : initial, attention: attention,
            customIcon: customIconFile, style: customIconFile ? "custom" : outlined ? "outline" : "tile",
            background: customIconFile || outlined ? "transparent" : String(icon.background),
            color: String(foreground), attentionColor: String(icon.attentionColor)};
    }
    function openMenu(event) { controller.openTrayMenu(modelData, button, event); }
    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: button.host.showTooltip(button, button.controller.trayTooltip(button.modelData))
        onExited: button.host.hideTooltip(button)
        onPressed: function(event) {
            if (event.button === Qt.RightButton) {
                button.dismissAttention();
                button.host.recordIconClick(button.usageKey);
                button.openMenu(event);
                event.accepted = true;
            }
        }
        onClicked: function(event) {
            if (event.button === Qt.RightButton) return;
            button.dismissAttention();
            button.host.recordIconClick(button.usageKey);
            if (event.button === Qt.MiddleButton) button.modelData.secondaryActivate();
            else if (button.modelData.onlyMenu) button.openMenu(event);
            else button.modelData.activate();
        }
        onWheel: function(event) { button.modelData.scroll(event.angleDelta.y, false); }
    }
    Component.onDestruction: host.hideTooltip(button)
}
