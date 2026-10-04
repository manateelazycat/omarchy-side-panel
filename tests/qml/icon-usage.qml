import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.Ui
import "Plugin" as Plugin
import "Plugin/Ui" as PanelUi

ShellRoot {
    id: root
    property int activations: 0
    property int menus: 0
    property int reloads: 0
    property var trayItem: ({id: "lzc-client-desktop_status_icon_1", icon: "", onlyMenu: false,
        activate: function() { root.activations++; },
        secondaryActivate: function() { root.activations++; },
        scroll: function() {}})
    function check(value, message) { if (!value) throw new Error(message); }
    Plugin.IconUsage { id: usage }
    Item {
        id: host
        property var options: ({pixelated: false, iconPixels: 16})
        property int barSize: 28
        property color foreground: "white"
        property color barForeground: foreground
        property color urgent: foreground
        property color background: "black"
        property string fontFamily: "monospace"
        property bool vertical: true
        property bool foregroundAnimationEnabled: false
        property bool recording: false
        property bool stayAwake: false
        property bool doNotDisturb: false
        function recordIconClick(key) { usage.record(key); }
        function showTooltip(target, text) {}
        function hideTooltip(target) {}
        function reloadShell() {
            root.check(JSON.parse(disk.text()).counts["action:reload"] === 1,
                "Reload ran before the count reached disk");
            root.reloads++;
        }
    }
    FileView { id: disk; path: usage.path; preload: false; blockLoading: true; printErrors: false }
    Item {
        id: controller
        function iconIsSymbolic(icon) { return false; }
        function trayIconSource(icon) { return icon; }
        function trayTooltip(item) { return item.id; }
        function openTrayMenu(item, button, event) { root.menus++; }
    }
    Window {
        id: window
        width: 160; height: 160; visible: true
        WidgetButton {
            id: native
            x: 10; y: 10; width: 40; height: 30; text: "x"
            onPressed: root.activations++
        }
        MouseArea {
            id: custom
            x: 10; y: 50; width: 40; height: 30
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        }
        Plugin.TrayButton {
            id: tray
            x: 60; y: 10
            host: host; controller: controller; modelData: root.trayItem
        }
        Plugin.ActionIcon {
            id: power
            x: 10; y: 90
            host: host; action: "power"
            onPressed: function(button) { if (button === Qt.LeftButton) root.menus++; }
        }
        Plugin.ActionIcon {
            id: reload
            x: 60; y: 90
            host: host; action: "reload"
        }
        Plugin.DockLayout {
            id: layout
            x: 110; width: 40; counts: usage.counts
            Item {
                id: cellA
                property string usageKey: "action:power"
                property int ordinal: 0
                height: 20; y: layout.cellY(cellA)
                Component.onCompleted: layout.registerCell(cellA)
            }
            Item {
                id: cellB
                property string usageKey: "widget:test"
                property int ordinal: 1
                height: 20; y: layout.cellY(cellB)
                Component.onCompleted: layout.registerCell(cellB)
            }
            Item {
                id: cellC
                property string usageKey: "tray:lzc-client-desktop_status_icon"
                property int ordinal: 2
                height: 20; y: layout.cellY(cellC)
                Component.onCompleted: layout.registerCell(cellC)
            }
        }
    }
    PanelUi.IconClickTracker {
        id: nativeTracker
        rootItem: native
        record: function() { usage.record("widget:test"); }
    }
    PanelUi.IconClickTracker {
        rootItem: custom
        record: function() { usage.record("widget:custom"); }
    }
    TestCase { id: mouse; when: false }
    Timer {
        interval: 200; running: true
        onTriggered: {
            try {
                var resumed = Quickshell.env("USAGE_PHASE") === "resume";
                if (resumed) {
                    root.check(usage.counts["widget:test"] === 3, "Native clicks were not restored");
                    root.check(usage.counts["widget:custom"] === 2, "Custom clicks were not restored");
                    root.check(usage.counts["tray:lzc-client-desktop_status_icon"] === 3, "Tray clicks were not restored");
                    root.check(usage.counts["action:reload"] === 1, "Immediate reload write was lost");
                    root.check(usage.counts["action:power"] === 1, "Power count was not restored");
                    root.check(layout.orderedCells[0] === cellA && cellA.y === 0, "Power menu lost first position after restart");
                    usage.record("widget:test");
                } else {
                    root.check(usage.ready && !usage.error, "Store did not load");
                    root.check(cellA.y === 0 && cellB.y === 24 && cellC.y === 48, "Initial order incorrect");
                    mouse.mouseClick(native, 20, 15, Qt.LeftButton);
                    mouse.mouseClick(native, 20, 15, Qt.RightButton);
                    mouse.mouseClick(native, 20, 15, Qt.MiddleButton);
                    mouse.mouseClick(custom, 20, 15, Qt.LeftButton);
                    mouse.mouseClick(custom, 20, 15, Qt.RightButton);
                    mouse.mouseClick(tray, 14, 14, Qt.LeftButton);
                    mouse.mouseClick(tray, 14, 14, Qt.RightButton);
                    mouse.mouseClick(tray, 14, 14, Qt.MiddleButton);
                    root.check(usage.counts["widget:test"] === 3, "Native activation duplicated or missed");
                    root.check(usage.counts["widget:custom"] === 2, "MouseArea activation duplicated or missed");
                    root.check(usage.counts["tray:lzc-client-desktop_status_icon"] === 3, "Tray activation duplicated or missed");
                    root.check(root.activations === 5 && root.menus === 1, "Native behavior changed");
                    root.check(layout.orderedCells[0] === cellA && layout.orderedCells[1] === cellB
                        && layout.orderedCells[2] === cellC,
                        "Cells were not ranked by usage");
                    root.check(cellA.y === 0 && cellB.y === 24 && cellC.y === 48, "Power menu was not pinned first");
                    nativeTracker.rootItem = null;
                    gc();
                    native.triggerPress(Qt.LeftButton);
                    root.check(usage.counts["widget:test"] === 3, "Old activation connection survived reset");
                    mouse.mouseClick(power, 14, 14, Qt.LeftButton);
                    mouse.mouseClick(reload, 14, 14, Qt.LeftButton);
                    root.check(usage.counts["action:power"] === 1, "Power click was not counted exactly once");
                    root.check(root.menus === 2 && root.reloads === 1, "Power/reload behavior changed");
                    root.check(!usage.error, "Atomic write failed: " + usage.error);
                }
                console.log("USAGE_PASS", resumed ? "resume" : "initial");
            } catch (error) { console.log("USAGE_FAIL", String(error)); }
            Qt.quit();
        }
    }
}
