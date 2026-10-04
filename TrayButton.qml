import QtQuick
import QtQuick.Window
import QtQuick.Effects
import Quickshell
import qs.Commons
import "UsageModel.js" as Usage
import "Ui" as PanelUi

// Individual tray cells share the existing plugin's menu controller.
Item {
    id: button
    required property var host
    required property var controller
    required property var modelData
    readonly property string usageKey: Usage.trayKey(modelData)
    readonly property color foreground: host.foreground
    readonly property bool tooltipHovered: visible && mouse.containsMouse
    readonly property var iconNormalizer: PanelUi.IconNormalizer {
        parent: button
        sourceItem: button
        targetSize: Style.bar.iconCanvas
    }
    readonly property var iconRasterizer: PanelUi.IconRasterizer {
        parent: button
        rootItem: button
        normalizeTrayIcons: false
        pixelated: button.host.options.pixelated
        pixels: button.host.options.iconPixels
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
    layer.effect: PanelUi.MonochromeIconEffect { smooth: !button.host.options.pixelated; ink: button.foreground; preserveTone: true }

    Item {
        id: icon
        anchors.centerIn: parent
        anchors.alignWhenCentered: false
        width: Style.bar.iconCanvas
        height: Style.bar.iconCanvas
        property var icon: button.modelData.icon
        readonly property bool symbolic: button.controller.iconIsSymbolic(icon)
        Image {
            id: trayImage
            anchors.fill: parent
            source: button.controller.trayIconSource(icon.icon)
            sourceSize: Qt.size(128, 128)
            fillMode: Image.PreserveAspectFit
            visible: !icon.symbolic
            layer.enabled: icon.symbolic
        }
        MultiEffect {
            anchors.fill: trayImage
            source: trayImage
            visible: icon.symbolic
            colorization: 1
            colorizationColor: "white"
        }
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
                button.host.recordIconClick(button.usageKey);
                button.openMenu(event);
                event.accepted = true;
            }
        }
        onClicked: function(event) {
            if (event.button === Qt.RightButton) return;
            button.host.recordIconClick(button.usageKey);
            if (event.button === Qt.MiddleButton) button.modelData.secondaryActivate();
            else if (button.modelData.onlyMenu) button.openMenu(event);
            else button.modelData.activate();
        }
        onWheel: function(event) { button.modelData.scroll(event.angleDelta.y, false); }
    }
    Component.onDestruction: host.hideTooltip(button)
}
