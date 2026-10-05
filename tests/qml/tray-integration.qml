import QtQuick
import QtTest
import Quickshell
import Quickshell.Services.SystemTray
import "Plugin" as Plugin

ShellRoot {
    id: root
    function check(value, message) { if (!value) throw new Error(message); }
    property var written: null
    property string phase: "controller load"
    Item {
        id: host
        property var barWidgetRegistry: null
        property var options: ({pixelated: false, iconPixels: 16})
        property int barSize: 28
        property bool vertical: true
        property string position: "left"
        property color foreground: "#dddddd"
        property string fontFamily: "monospace"
        property var layoutConfig: ({right: [{id: "omarchy.tray"}, {id: "omarchy.dropbox"}]})
        property var shell: QtObject {
            function updateEntryInline(id, settings) {
                root.check(id === "omarchy.tray", "Settings were written to the removed plugin");
                root.written = settings;
                slot.entry = settings;
                return true;
            }
        }
        function registerModuleSlot(slot) {}
        function unregisterModuleSlot(slot) {}
        function releasePopout(item) {}
        function requestPopout(item) {}
        function targetBelongsToWindow(target, window) { return true; }
        function registerClickTarget(target) {}
        function unregisterClickTarget(target) {}
        function showTooltip(target, text) {}
        function hideTooltip(target) {}
        function targetTooltipHovered(target) { return false; }
        function pluginBarApiFor(id) { throw new Error("Internal tray requested external plugin API"); }
    }
    FloatingWindow {
        visible: true; implicitWidth: 400; implicitHeight: 400
        Item { id: anchor; x: 20; y: 20; width: 28; height: 28 }
        Plugin.WidgetSlot {
            id: slot
            host: host
            entry: ({id: "omarchy.tray", pinned: ["pin"], hidden: ["hide"], custom: 17})
        }
    }
    TestCase { id: input; when: false }
    function names(items) { return items.map(function(item) { return item.id; }).join(","); }
    Timer {
        interval: 200; running: true
        onTriggered: {
            try {
                var tray = slot.activeItem;
                check(tray && slot.expandedTray && slot.naturalHeight === 0, "No internal controller without registry");
                check(!tray.visible && tray.implicitHeight === 0, "Controller reserved an empty icon slot");
                tray.items = [
                    {id: "active", status: Status.Active}, {id: "pin", status: Status.Active},
                    {id: "hide", status: Status.Active}, {id: "passive", status: Status.Passive},
                    {id: "attention", status: Status.NeedsAttention},
                    {id: "localsend-random", status: Status.Active}, {id: "dropbox", status: Status.Active}
                ];
                check(names(slot.trayItems) === "active,attention,pin", "Filtering or pin grouping changed");
                check(names(tray.allItems) === "active,pin,hide,attention", "Hidden items cannot be managed");
                tray.togglePin("hide");
                input.wait(30);
                check(names(slot.trayItems) === "active,attention,pin,hide", "Pin did not unhide the item: " + JSON.stringify({entry: slot.entry, settings: tray.settings, visible: names(slot.trayItems)}));
                check(root.written.custom === 17 && root.written.hidden.length === 0, "Settings lost during pin");
                tray.toggleHide("pin");
                input.wait(30);
                check(names(slot.trayItems) === "active,attention,hide" && tray.pinnedIds.indexOf("pin") === -1,
                    "Hiding a pinned item did not update the live model");
                tray.items = [];
                check(slot.trayItems.length === 0 && slot.naturalHeight === 0, "Empty tray left spacing");
                tray.items = Qt.binding(function() { return SystemTray.items.values; });
                phase = "native item registration";
                input.tryVerify(function() { return tray.items.length === 1 && tray.items[0].menu; }, 5000);
                check(tray.items.length === 1 && tray.items[0].menu, "Native test tray did not register");
                tray.openTrayMenu(tray.items[0], anchor, {x: 5, y: 5});
                phase = "root menu";
                input.tryVerify(function() { return tray.currentChildren.values.length > 0; }, 3000);
                check(tray.trayMenuOpen, "Context menu did not open");
                var nested = tray.currentChildren.values[0];
                check(nested.text === "Nested" && nested.hasChildren, "Missing first submenu");
                tray.enterSubmenu(nested, nested.text);
                phase = "first submenu";
                input.tryVerify(function() { return tray.currentChildren.values.length > 0; }, 3000);
                var deep = tray.currentChildren.values[0];
                check(tray.submenuDepth === 1 && deep.text === "Deep", "First submenu lost its opener");
                tray.enterSubmenu(deep, deep.text);
                phase = "second submenu";
                input.tryVerify(function() { return tray.currentChildren.values.length > 0; }, 3000);
                check(tray.submenuDepth === 2 && tray.currentChildren.values[0].text === "Action", "Deep submenu is empty");
                tray.currentChildren.values[0].triggered();
                input.wait(100);
                tray.leaveSubmenu();
                check(tray.submenuDepth === 1 && tray.currentChildren.values[0].text === "Deep", "Back lost parent entries");
                tray.close();
                phase = "menu close";
                input.tryVerify(function() { return tray.submenuDepth === 0; }, 1500);
                check(!tray.trayMenuOpen && tray.submenuDepth === 0, "Close did not clean up nested openers");
                console.log("TRAY_INTEGRATION_PASS");
            } catch (error) { console.log("TRAY_INTEGRATION_FAIL", phase, String(error)); }
            Qt.quit();
        }
    }
    Timer { interval: 18000; running: true; onTriggered: { console.log("TRAY_INTEGRATION_FAIL timeout"); Qt.quit(); } }
}
