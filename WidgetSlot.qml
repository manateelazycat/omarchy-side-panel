import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons
import "SidePanelModel.js" as Model
import "Ui" as PanelUi

Item {
    id: root
    required property var host
    required property var entry
    property string region: "right"
    readonly property string moduleName: Model.entryId(entry)
    readonly property var settings: Model.entrySettings(entry)
    readonly property var registration: host.barWidgetRegistry ? host.barWidgetRegistry.widgets[moduleName] : null
    readonly property bool firstParty: registration && registration.metadata && registration.metadata.firstParty === true
    readonly property string tooltipText: Model.tooltipLabel(moduleName, registration ? registration.metadata : null)
    readonly property bool tooltipHovered: slotHover.hovered && naturalHeight > 0
    property var activeItem: null
    property var loadedComponent: null
    property var widgetApi: null
    readonly property bool expandedTray: moduleName === "io.github.manateelazycat.tray-bar"
        && activeItem && typeof activeItem.openTrayMenu === "function"
    readonly property var trayItems: expandedTray ? activeItem.drawerItems.concat(activeItem.pinnedItems) : []
    readonly property real naturalHeight: !expandedTray && activeItem && activeItem.visible ? Math.max(1, activeItem.implicitHeight) : 0
    implicitWidth: host.barSize
    implicitHeight: naturalHeight
    width: implicitWidth
    height: implicitHeight

    // Desaturate every visual child, including app icons and active states.
    // Decode SVGs above display resolution, including the hover enlargement.
    layer.enabled: naturalHeight > 0
    layer.textureSize: host.options.pixelated
        ? Qt.size(Math.max(1, Math.round(width * host.options.iconPixels / Style.bar.iconCanvas)),
            Math.max(1, Math.round(height * host.options.iconPixels / Style.bar.iconCanvas)))
        : Qt.size(Math.ceil(width * Screen.devicePixelRatio * 4), Math.ceil(height * Screen.devicePixelRatio * 4))
    layer.smooth: !host.options.pixelated
    layer.mipmap: false
    layer.effect: PanelUi.MonochromeIconEffect { smooth: !root.host.options.pixelated; ink: root.host.foreground }
    layer.sourceRect: iconNormalizer.sourceRect
    readonly property var iconNormalizer: PanelUi.IconNormalizer {
        parent: root
        sourceItem: root.expandedTray ? null : root.activeItem
        // A tray contains several icons; its rasterizer normalizes each one.
        normalize: root.moduleName !== "io.github.manateelazycat.tray-bar"
        targetSize: Style.bar.iconCanvas
    }
    readonly property var iconRasterizer: PanelUi.IconRasterizer {
        parent: root
        rootItem: root.expandedTray ? null : root.activeItem
        glyphFiles: root.moduleName === "omarchy.bluetooth"
            ? ({"󰂯": "widgets/bluetooth.svg", "󰂱": "widgets/bluetooth.svg", "󰂲": "widgets/bluetooth.svg"})
            : root.moduleName === "omarchy.network" ? ({
                "󰈀": "widgets/network.svg", "󰤮": "widgets/network.svg",
                "󰤯": "widgets/network.svg", "󰤟": "widgets/network.svg",
                "󰤢": "widgets/network.svg", "󰤥": "widgets/network.svg", "󰤨": "widgets/network.svg"
            }) : root.moduleName === "omarchy.audio" ? ({
                "": "widgets/audio.svg", "󰋋": "widgets/audio.svg",
                "": "widgets/audio.svg", "": "widgets/audio.svg", "": "widgets/audio.svg"
            }) : root.moduleName === "crmne.hyprmoncfg" || root.moduleName === "omarchy.monitor"
                ? ({"󰍺": "widgets/monitors.svg", "󰍹": "widgets/monitors.svg"}) : ({})
        pixelated: root.host.options.pixelated
        pixels: root.host.options.iconPixels
    }

    readonly property var popupStyler: PanelUi.PopupStyler { rootObject: root.activeItem; label: root.moduleName }
    // Retain the native tray's menu/state owner; render its apps as individual
    // dock cells so their counts can be compared with every other icon.
    Binding {
        target: root.activeItem
        property: "visible"
        value: false
        when: root.expandedTray
        restoreMode: Binding.RestoreBindingOrValue
    }
    PanelUi.IconClickTracker {
        rootItem: root.expandedTray ? null : root.activeItem
        record: function() { root.host.recordIconClick("widget:" + root.moduleName); }
    }

    // Plugins keep their own per-icon text (including individual tray apps).
    // Supply a label only when the hovered child has not requested a tooltip.
    HoverHandler {
        id: slotHover
        onHoveredChanged: {
            if (hovered) {
                Qt.callLater(function() {
                    if (root.tooltipHovered && !root.host.targetTooltipHovered(root.host.tooltipTarget))
                        root.host.showTooltip(root, root.tooltipText);
                });
            } else root.host.hideTooltip(root);
        }
    }

    function inject() {
        var item = activeItem;
        if (!item) return;
        widgetApi = firstParty ? host : host.pluginBarApiFor(moduleName);
        if ("bar" in item) item.bar = widgetApi;
        if ("moduleName" in item) item.moduleName = moduleName;
        if ("settings" in item) item.settings = settings;
    }

    function rebuild() {
        var component = registration ? registration.component : null;
        if (loadedComponent === component) return;
        if (activeItem) { host.releasePopout(activeItem); activeItem.destroy(); activeItem = null; }
        loadedComponent = component;
        if (!component) return;
        widgetApi = firstParty ? host : host.pluginBarApiFor(moduleName);
        activeItem = component.createObject(root, {bar: widgetApi, moduleName: moduleName, settings: settings});
        if (!activeItem) { console.warn("Side panel widget failed:", moduleName, component.errorString()); return; }
        activeItem.width = Qt.binding(function() { return root.width; });
        activeItem.height = Qt.binding(function() { return root.height; });
    }
    onRegistrationChanged: rebuild()
    onEntryChanged: inject()
    Component.onCompleted: { host.registerModuleSlot(root); rebuild(); }
    Component.onDestruction: host.unregisterModuleSlot(root)
}
