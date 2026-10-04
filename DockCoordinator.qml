import QtQuick

// One reveal at a time. A new edge must dwell and every old dock must finish
// closing before the target can start opening at its fixed screen edge.
Item {
    id: coordinator
    required property var host
    property var candidate: null
    property string candidateSide: ""
    property bool dwellReady: false
    property bool changing: false
    readonly property bool dwellPending: dwell.running

    function cancel(surface) {
        if (surface && candidate !== surface) return;
        dwell.stop();
        candidate = null;
        candidateSide = "";
        dwellReady = false;
    }
    function request(surface, side) {
        if (changing) return;
        if (host.barHidden || !side || (surface.shown && surface.dockSide === side)) return;
        if (candidate === surface && candidateSide === side) return;
        changing = true;
        try {
            candidate = surface;
            candidateSide = side;
            dwellReady = false;
            host.dismissDockPopout();
            host.clearTooltip();
            host.surfaces.forEach(function(item) { item.revealed = false; });
        } finally { changing = false; }
        if (candidate) dwell.restart();
    }
    function advance() {
        if (changing || !candidate || !dwellReady) return;
        if (host.barHidden || candidate.edgeSide !== candidateSide) { cancel(); return; }
        if (host.activePopout || host.surfaces.some(function(item) { return item.shown || item.revealProgress > 0; })) return;
        var target = candidate;
        var side = candidateSide;
        cancel();
        target.revealAt(side);
    }
    function snapshot() {
        return {screen: candidate && candidate.screen ? candidate.screen.name : "",
            side: candidateSide, dwellPending: dwellPending, dwellReady: dwellReady};
    }
    Timer {
        id: dwell
        interval: coordinator.host.options.showDelay
        onTriggered: { coordinator.dwellReady = true; coordinator.advance(); }
    }
    Component.onDestruction: cancel()
}
