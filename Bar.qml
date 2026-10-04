import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui
import "SidePanelModel.js" as Model
import "UsageModel.js" as Usage
import "Ui" as PanelUi

Item {
    id: root
    property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
    property var shell: null
    property var manifest: null
    property var pluginRegistry: null
    property var barWidgetRegistry: null
    property var barConfig: ({})
    property var layoutConfig: ({left: [], center: [], right: []})
    readonly property var options: Model.options(barConfig)
    readonly property var rightEntries: Model.rightEntries(layoutConfig)
    readonly property string position: {
        var window = targetWindow(activePopout || tooltipTarget);
        if (window && "dockSide" in window) return window.dockSide;
        var hovered = surfaces.find(function(surface) { return surface.pointerHovered; });
        return hovered ? hovered.dockSide : "left";
    }
    readonly property bool vertical: true
    readonly property int barSize: Style.bar.sizeVertical
    readonly property bool transparent: false
    readonly property string fontFamily: Style.font.family
    readonly property color foreground: Color.bar.text
    readonly property color barForeground: foreground
    readonly property color background: Color.bar.background
    readonly property color urgent: Color.bar.active
    readonly property bool foregroundAnimationEnabled: true
    readonly property bool centerSectionRevealHeld: true
    property bool centerHoverRevealSuppressed: false
    property bool barHidden: false
    property var activePopout: null
    property string activePopoutPluginId: ""
    property var clickTargets: []
    property var pluginClickTargets: []
    property var moduleSlots: []
    property var surfaces: []
    readonly property var dockCoordinator: handoff
    property var orderCounts: ({})
    property var widgetApis: ({})
    property var serviceBridges: ({})
    property var tooltipTarget: null
    property string tooltipText: ""
    property bool tooltipShown: false
    property bool recording: false
    readonly property var idleService: shell ? shell.firstPartyServiceFor("omarchy.idle") : null
    readonly property var notificationService: shell ? shell.firstPartyServiceFor("omarchy.notifications") : null
    readonly property bool stayAwake: idleService ? idleService.stayAwake : false
    readonly property bool doNotDisturb: notificationService ? notificationService.doNotDisturb : false

    IconUsage {
        id: iconUsage
        onCountsChanged: root.refreshIconOrder()
    }
    TrayRecovery { id: trayRecovery }
    readonly property var trayAttention: TrayAttention {}
    DockCoordinator { id: handoff; host: root }
    function dismissDockPopout() {
        var owner = activePopout;
        if (!owner) return;
        if (typeof owner.closeForPopoutSwitch === "function") owner.closeForPopoutSwitch();
        else if (typeof owner.close === "function") owner.close();
        releasePopout(owner);
    }
    onActivePopoutChanged: handoff.advance()
    function recordIconClick(key) { iconUsage.record(key); }
    function iconClickCount(key) { return Usage.countFor(iconUsage.counts, key); }
    function refreshIconOrder() {
        if (!activePopout && !surfaces.some(function(surface) { return surface.shown || surface.revealProgress > 0; }))
            orderCounts = Object.assign({}, iconUsage.counts);
    }

    function run(command) { Quickshell.execDetached(["bash", "-c", String(command)]); }
    function shellQuote(value) { return Util.shellQuote(value); }
    function setCenterHoverRevealSuppressed(value) { centerHoverRevealSuppressed = !!value; }
    function registerClickTarget(target) {
        if (clickTargets.indexOf(target) === -1) clickTargets = clickTargets.concat([target]);
    }
    function unregisterClickTarget(target) { clickTargets = clickTargets.filter(function(item) { return item !== target; }); }
    function registerModuleSlot(slot) { moduleSlots = moduleSlots.concat([slot]); }
    function unregisterModuleSlot(slot) {
        if (activePopout === slot.activeItem) activePopout = null;
        moduleSlots = moduleSlots.filter(function(item) { return item !== slot; });
    }
    function registerSurface(surface) { surfaces = surfaces.concat([surface]); }
    function unregisterSurface(surface) {
        handoff.cancel(surface);
        surfaces = surfaces.filter(function(item) { return item !== surface; });
    }
    function targetWindow(target) {
        if (!target) return null;
        if ("contentItem" in target && "screen" in target) return "currentWindow" in target ? target.currentWindow : target;
        return target.QsWindow ? target.QsWindow.window : null;
    }
    function targetBelongsToWindow(target, window) {
        var actual = targetWindow(target);
        return actual === window || (actual && "dockOwner" in actual && actual.dockOwner === window);
    }
    function slotSnapshot(slot) {
        var window = targetWindow(slot);
        var point = slot.mapToItem(null, slot.width / 2, slot.height / 2);
        return {id: slot.moduleName, screen: window && window.screen ? window.screen.name : "",
            x: point.x, y: point.y, loaded: !!slot.activeItem,
            visible: slot.activeItem ? slot.activeItem.visible : false,
            naturalHeight: slot.naturalHeight, popups: slot.popupStyler.snapshot(),
            normalization: slot.iconNormalizer.snapshot(),
            vectorGlyphs: slot.iconRasterizer.glyphSnapshot(),
            pixelation: {enabled: slot.layer.enabled, smooth: slot.layer.smooth,
                textureWidth: slot.layer.textureSize.width, textureHeight: slot.layer.textureSize.height,
                images: slot.iconRasterizer.snapshot()}};
    }
    function moduleWidgets(id) {
        return moduleSlots.filter(function(slot) { return slot.moduleName === id && slot.activeItem; })
            .map(function(slot) { return slot.activeItem; });
    }
    function findPanelWidget(id) {
        var items = moduleWidgets(id).filter(function(item) { return typeof item.open === "function" && typeof item.close === "function"; });
        var focused = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        return items.find(function(item) { var window = targetWindow(item); return window && window.screen.name === focused; }) || items[0] || null;
    }
    function summonBarWidget(id) { var item = findPanelWidget(id); if (!item) return false; item.open(); return true; }
    function hideBarWidget(id) { var item = findPanelWidget(id); if (!item) return false; item.close(); return true; }
    function isBarWidgetOpen(id) { var item = findPanelWidget(id); return !!item && item.opened === true; }
    function panelWidgetIdAt(region, index) {
        var ids = rightEntries.map(Model.entryId).filter(function(id) { return !!findPanelWidget(id); })
            .sort(function(a, b) { return Usage.countFor(orderCounts, "widget:" + b) - Usage.countFor(orderCounts, "widget:" + a); });
        return region === "right" ? ids[Number(index) - 1] || "" : "";
    }
    function switchPanelFrom(owner, direction) {
        var current = moduleSlots.find(function(slot) { return slot.activeItem === owner; });
        if (!current) return false;
        var window = targetWindow(owner);
        var slots = moduleSlots.filter(function(slot) {
            var item = slot.activeItem;
            return targetWindow(item) === window && item && item.visible && typeof item.open === "function" && typeof item.close === "function";
        }).sort(function(a, b) { return a.mapToItem(null, 0, 0).y - b.mapToItem(null, 0, 0).y; });
        var index = slots.indexOf(current);
        if (slots.length < 2 || index < 0) return false;
        slots[(index + (direction < 0 ? -1 : 1) + slots.length) % slots.length].activeItem.open();
        return true;
    }
    function requestPopout(owner, pluginId) {
        if (activePopout === owner) return;
        if (activePopout) {
            if (typeof activePopout.closeForPopoutSwitch === "function") activePopout.closeForPopoutSwitch();
            else if (typeof activePopout.close === "function") activePopout.close();
        }
        activePopout = owner;
        activePopoutPluginId = pluginId || "";
        clearTooltip();
    }
    function releasePopout(owner) { if (activePopout === owner) { activePopout = null; activePopoutPluginId = ""; } }
    function slotForTarget(target) {
        for (var item = target; item; item = item.parent) {
            if (moduleSlots.indexOf(item) !== -1) return item;
        }
        return null;
    }
    function targetTooltipHovered(target) {
        return !!target && target.visible !== false && target.opacity !== 0 && target.tooltipHovered === true;
    }
    function showTooltip(target, text) {
        if (!target) return;
        var slot = slotForTarget(target);
        text = String(text || "").trim() || (slot ? slot.tooltipText : "");
        if (!text) return;
        if (tooltipTarget === target && tooltipText === text && (tooltipShown || tooltipTimer.running)) return;
        tooltipTarget = target;
        tooltipText = text;
        tooltipShown = false;
        tooltipTimer.restart();
    }
    function hideTooltip(target) { if (tooltipTarget === target) clearTooltip(); }
    function clearTooltip() { tooltipTimer.stop(); tooltipShown = false; tooltipTarget = null; tooltipText = ""; }

    Component { id: apiComponent; PluginBarApi {} }
    Component { id: bridgeComponent; ServiceBridge {} }
    function pluginBarApiFor(id) {
        if (widgetApis[id]) return widgetApis[id];
        var entryShell = shell && typeof shell.pluginShellForBarEntry === "function" ? shell.pluginShellForBarEntry(id, id) : null;
        if (Model.serviceBridgeId(id)) {
            var bridge = bridgeComponent.createObject(root, {pluginId: id, delegateShell: entryShell});
            serviceBridges[id] = bridge;
            entryShell = bridge;
        }
        var api = apiComponent.createObject(root, {
            pluginId: id, moduleName: id, shell: entryShell,
            _showTooltip: function(target, text) { root.showTooltip(target, text); },
            _hideTooltip: function(target) { root.hideTooltip(target); },
            _registerClickTarget: function(target) {
                root.registerClickTarget(target);
                root.pluginClickTargets = root.pluginClickTargets.filter(function(record) { return record.target !== target; }).concat([{id: id, target: target}]);
            },
            _unregisterClickTarget: function(target) {
                root.unregisterClickTarget(target);
                root.pluginClickTargets = root.pluginClickTargets.filter(function(record) { return record.target !== target; });
            },
            _requestPopout: function(owner) { root.requestPopout(owner, id); },
            _releasePopout: function(owner) { root.releasePopout(owner); },
            _switchPanelFrom: function(owner, direction) { return root.switchPanelFrom(owner, direction); },
            _targetBelongsToWindow: function(target, window) { return root.targetBelongsToWindow(target, window); },
            _moduleWidgets: function(requestedId) { return requestedId === id ? root.moduleWidgets(id) : []; },
            _run: function(command) { root.run(command); },
            _setCenterHoverRevealSuppressed: function(value) { root.setCenterHoverRevealSuppressed(value); }
        });
        api.foreground = Qt.binding(function() { return root.foreground; });
        api.barForeground = Qt.binding(function() { return root.barForeground; });
        api.background = Qt.binding(function() { return root.background; });
        api.urgent = Qt.binding(function() { return root.urgent; });
        api.fontFamily = Qt.binding(function() { return root.fontFamily; });
        api.position = Qt.binding(function() { return root.position; });
        api.vertical = true;
        api.barSize = root.barSize;
        api.foregroundAnimationEnabled = true;
        api.centerSectionRevealHeld = true;
        api.activePopout = Qt.binding(function() { return root.activePopoutPluginId === id ? root.activePopout : (root.activePopout ? api.foreignPopoutMarker : null); });
        api.clickTargets = Qt.binding(function() { return root.pluginClickTargets.filter(function(record) { return record.id === id; }).map(function(record) { return record.target; }); });
        api.layoutConfig = Qt.binding(function() { return JSON.parse(JSON.stringify(root.layoutConfig)); });
        var next = Object.assign({}, widgetApis); next[id] = api; widgetApis = next;
        return api;
    }
    function applyConfig() {
        var next = barConfig.layout || {left: [], center: [], right: []};
        // Inline settings updates must keep open widgets alive.
        var same = ["left", "center", "right"].every(function(section) {
            return JSON.stringify((next[section] || []).map(Model.entryId)) === JSON.stringify((layoutConfig[section] || []).map(Model.entryId));
        });
        if (!same) layoutConfig = JSON.parse(JSON.stringify(next));
        else {
            ["left", "center", "right"].forEach(function(section) { layoutConfig[section] = next[section] || []; });
            moduleSlots.forEach(function(slot) {
                var entry = (next[slot.region] || []).find(function(item) { return Model.entryId(item) === slot.moduleName; });
                if (entry) slot.entry = entry;
            });
        }
    }
    onBarConfigChanged: applyConfig()
    Component.onCompleted: { applyConfig(); refreshIconOrder(); }
    Timer {
        id: tooltipTimer
        interval: 350
        onTriggered: {
            if (root.targetTooltipHovered(root.tooltipTarget)) root.tooltipShown = true;
            else root.clearTooltip();
        }
    }
    Timer {
        interval: 100
        running: root.tooltipShown
        repeat: true
        onTriggered: if (!root.targetTooltipHovered(root.tooltipTarget)) root.clearTooltip()
    }
    Process {
        id: recordingProbe
        command: ["pgrep", "--quiet", "-f", "^gpu-screen-recorder"]
        onExited: function(code) { root.recording = code === 0; }
    }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!recordingProbe.running) recordingProbe.running = true }
    function toggleRecording() {
        var command = root.recording
            ? ["omarchy", "capture", "screenrecording", "--stop-recording"]
            : ["omarchy", "menu", "toggle", "trigger.capture.screenrecord"];
        Quickshell.execDetached(command);
    }
    function toggleIdle() { if (idleService) idleService.setIdleEnabled(stayAwake); }
    function toggleNotifications() { if (notificationService) notificationService.setDoNotDisturb(!doNotDisturb); }
    function reloadShell() { Quickshell.execDetached(["omarchy", "restart", "shell"]); }
    Process {
        id: hiddenProbe
        command: ["test", "-f", Quickshell.env("HOME") + "/.local/state/omarchy/toggles/bar-off"]
        running: true
        onExited: function(code) { root.barHidden = code === 0; }
    }
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/omarchy/toggles"
        watchChanges: true
        printErrors: false
        onFileChanged: hiddenProbe.running = true
    }
    IpcHandler { target: "omarchy.bar"; function syncHidden(): void { hiddenProbe.running = true; } }
    IpcHandler { target: "omarchy.indicators"; function refresh(): void { recordingProbe.running = true; } }
    IpcHandler {
        target: "andy.side-panel"
        function status(): string {
            return JSON.stringify({id: "andy.side-panel", position: root.position, recording: root.recording,
                stayAwake: root.stayAwake, doNotDisturb: root.doNotDisturb,
                pixelated: root.options.pixelated, iconPixels: root.options.iconPixels,
                usage: iconUsage.snapshot(),
                trayRecovery: trayRecovery.snapshot(),
                trayAttention: root.trayAttention.snapshot(),
                handoff: handoff.snapshot(),
                popupStyle: PanelUi.PopupAppearance.snapshot(),
                tooltip: {shown: root.tooltipShown, text: root.tooltipText,
                    screen: root.targetWindow(root.tooltipTarget) && root.targetWindow(root.tooltipTarget).screen
                        ? root.targetWindow(root.tooltipTarget).screen.name : ""},
                widgets: root.rightEntries.map(Model.entryId),
                slots: root.moduleSlots.map(root.slotSnapshot),
                screens: root.surfaces.map(function(surface) { return surface.stateSnapshot(); })});
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: DockSurface { required property var modelData; screen: modelData; host: root }
    }
}
