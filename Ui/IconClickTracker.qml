import QtQuick

// Observe native activation signals without taking or forwarding mouse events.
Item {
    id: tracker
    property var rootItem: null
    property var record: null
    property var watches: []
    property var seen: new Set()
    property bool disposing: false

    Component {
        id: nativeButtonWatch
        Connections {
            function onPressed(button) { if (tracker.record) tracker.record(); }
        }
    }
    Component {
        id: mouseWatch
        Connections {
            function onClicked(mouse) {
                if (mouse.button !== Qt.RightButton && tracker.record) tracker.record();
            }
            // Tray and custom context menus may grab the pointer on press.
            function onPressed(mouse) {
                if (mouse.button === Qt.RightButton && tracker.record) tracker.record();
            }
        }
    }
    Component {
        id: childWatch
        Connections {
            function onChildrenChanged() { if (!tracker.disposing) refresh.restart(); }
        }
    }
    function visit(item) {
        if (!item || seen.has(item) || "sidePanelVectorGlyph" in item || "sidePanelIconNormalizer" in item) return;
        seen.add(item);
        if ("triggerPress" in item && "pressed" in item) {
            watches.push(nativeButtonWatch.createObject(tracker, {target: item}));
            // Its MouseArea emits the same activation; observe it only once.
            return;
        }
        if ("acceptedButtons" in item && "containsMouse" in item && "clicked" in item)
            watches.push(mouseWatch.createObject(tracker, {target: item}));
        if ("children" in item) {
            watches.push(childWatch.createObject(tracker, {target: item}));
            for (var i = 0; i < item.children.length; i++) visit(item.children[i]);
        }
    }
    function disconnect() {
        watches.forEach(function(watch) { if (watch) { watch.target = null; watch.destroy(); } });
        watches = [];
        seen = new Set();
    }
    function reset() {
        refresh.stop();
        disconnect();
        if (!disposing) refresh.restart();
    }
    onRootItemChanged: reset()
    Component.onCompleted: refresh.restart()
    Component.onDestruction: { disposing = true; reset(); record = null; }
    Timer {
        id: refresh
        interval: 0
        onTriggered: if (!tracker.disposing) { tracker.disconnect(); tracker.visit(tracker.rootItem); }
    }
}
