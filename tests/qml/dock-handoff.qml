import QtQuick
import QtTest
import Quickshell
import "Plugin" as Plugin

ShellRoot {
    id: root
    property var openings: []
    property string failure: ""
    function check(value, message) { if (!value) throw new Error(message); }
    Item {
        id: host
        property var options: ({showDelay: 80})
        property bool barHidden: false
        property var activePopout: null
        property var surfaces: [a, b, c]
        function clearTooltip() {}
        function dismissDockPopout() { activePopout = null; }
    }
    Plugin.DockCoordinator { id: handoff; host: host }
    component FakeDock: Item {
        id: dock
        required property string name
        property var screen: ({name: name})
        property string edgeSide: ""
        property bool onRight: false
        readonly property string dockSide: onRight ? "right" : "left"
        property bool revealed: false
        readonly property bool shown: revealed
        property real revealProgress: shown ? 1 : 0
        Behavior on revealProgress { NumberAnimation { duration: 300 } }
        // Reproduce the real surface's synchronous hover re-evaluation when
        // it starts closing, including an old edge's not-yet-delivered leave.
        onShownChanged: if (edgeSide) handoff.request(dock, edgeSide)
        onRevealProgressChanged: if (revealProgress === 0) handoff.advance()
        function revealAt(side) {
            root.check(!host.surfaces.some(function(item) { return item.revealProgress > 0 || item.shown; }),
                "Opened a dock before the previous animation finished");
            onRight = side === "right";
            revealed = true;
            root.openings = root.openings.concat([name + ":" + side]);
        }
    }
    FakeDock { id: a; name: "A" }
    FakeDock { id: b; name: "B" }
    FakeDock { id: c; name: "C" }
    TestCase { id: wait; when: false }
    Timer {
        interval: 5; repeat: true; running: true
        onTriggered: {
            var visible = host.surfaces.filter(function(item) { return item.revealProgress > 0; });
            if (visible.length > 1) root.failure = "Two dock animations overlap";
        }
    }
    Timer {
        interval: 50; running: true
        onTriggered: {
            try {
                a.edgeSide = "left";
                handoff.request(a, "left");
                wait.wait(420);
                root.check(a.shown && a.revealProgress === 1, "Initial dock did not open");

                // Keep the old hover true until after the new request, to
                // exercise synchronous old-surface signal reentrancy.
                b.edgeSide = "right";
                handoff.request(b, "right");
                a.edgeSide = "";
                root.check(!a.shown && !b.shown && handoff.candidate === b, "Cross-monitor request was lost");
                wait.wait(150);
                root.check(a.revealProgress > 0 && !b.shown && !b.onRight, "New dock/side changed during close");
                wait.wait(500);
                root.check(a.revealProgress === 0 && b.shown && b.onRight, "Cross-monitor handoff failed");

                b.edgeSide = "left";
                handoff.request(b, "left");
                wait.wait(150);
                root.check(!b.shown && b.onRight && b.revealProgress > 0, "Same-screen side moved before hiding");
                wait.wait(500);
                root.check(b.shown && !b.onRight, "Same-screen left reveal failed");

                b.edgeSide = "";
                a.edgeSide = "right";
                handoff.request(a, "right");
                wait.wait(25);
                a.edgeSide = "";
                handoff.cancel(a);
                c.edgeSide = "left";
                handoff.request(c, "left");
                wait.wait(650);
                root.check(!a.shown && !b.shown && c.shown, "Rapid movement revealed a stale target");
                root.check(root.openings.join(",") === "A:left,B:right,B:left,C:left", "Unexpected reveal sequence");

                c.edgeSide = "";
                a.edgeSide = "left";
                handoff.request(a, "left");
                a.edgeSide = "";
                handoff.cancel(a);
                wait.wait(400);
                root.check(!host.surfaces.some(function(item) { return item.shown; }), "Leaving edge did not cancel reveal");
                root.check(!root.failure, root.failure);
                console.log("HANDOFF_PASS", root.openings.join(","));
            } catch (error) { console.log("HANDOFF_FAIL", String(error)); }
            Qt.quit();
        }
    }
}
