import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Ui as ShellUi
import "Plugin" as Plugin
import "Plugin/Ui" as PanelUi

ShellRoot {
    id: root
    property string failure: ""
    function check(value, message) { if (!value) throw new Error(message); }
    Item {
        id: testHost
        property var options: ({iconSize: 28, magnification: 1.28, hideDistance: 24, triggerWidth: 2,
            showDelay: 150, hideDelay: 80, animationDuration: 80, pixelated: false, iconPixels: 16})
        property bool barHidden: false
        property int barSize: 28
        property color foreground: "#dddddd"
        property color barForeground: foreground
        property color background: "#181818"
        property color urgent: foreground
        property string fontFamily: "monospace"
        property bool foregroundAnimationEnabled: false
        property bool vertical: true
        property string position: "left"
        property bool recording: false
        property bool stayAwake: false
        property bool doNotDisturb: false
        property var activePopout: null
        property var tooltipTarget: null
        property bool tooltipShown: false
        property string tooltipText: ""
        property var rightEntries: []
        property var orderCounts: ({})
        property var surfaces: []
        readonly property var dockCoordinator: handoff
        function clearTooltip() {}
        function dismissDockPopout() { activePopout = null; }
        function hideTooltip(target) {}
        function showTooltip(target, text) {}
        function registerClickTarget(target) {}
        function unregisterClickTarget(target) {}
        function recordIconClick(key) {}
        function iconClickCount(key) { return 0; }
        function refreshIconOrder() {}
        function registerSurface(surface) { surfaces = surfaces.concat([surface]); }
        function unregisterSurface(surface) { surfaces = surfaces.filter(item => item !== surface); }
        function requestPopout(target) { activePopout = target; }
        function releasePopout(target) { if (activePopout === target) activePopout = null; }
        function targetBelongsToWindow(target, window) { return target === window; }
    }
    Plugin.DockCoordinator { id: handoff; host: testHost }
    Variants {
        model: Quickshell.screens
        delegate: Plugin.DockSurface { required property var modelData; screen: modelData; host: testHost }
    }
    TestCase { id: input; when: false }
    property var referenceWindow: null
    PopupWindow {
        id: tooltipReference
        visible: !!root.referenceWindow
        color: "transparent"
        mask: Region {}
        implicitWidth: 120; implicitHeight: 40
        anchor {
            window: root.referenceWindow
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | (root.referenceWindow && root.referenceWindow.dockOwner.onRight ? Edges.Left : Edges.Right)
            rect.width: 1; rect.height: 1; rect.y: 100
            rect.x: !root.referenceWindow ? 0 : root.referenceWindow.dockOwner.onRight
                ? root.referenceWindow.width - root.referenceWindow.dockOwner.dockWidth - PanelUi.PopupAppearance.horizontalGap
                : root.referenceWindow.dockOwner.dockWidth + PanelUi.PopupAppearance.horizontalGap
        }
    }
    Component {
        id: nativeWidgetFactory
        Item {
            id: nativeWidget
            readonly property bool preservePopupContentAppearance: true
            property alias popup: popup
            property alias panel: panel
            property alias styler: nativeStyle
            Item { id: button; x: 16; y: 120; width: 28; height: 27; scale: 1.75; opacity: 0 }
            ShellUi.PopupCard {
                id: popup
                bar: testHost; anchorItem: button; owner: nativeWidget
                contentWidth: 240; contentHeight: 140
            }
            ShellUi.KeyboardPanel {
                id: panel
                bar: testHost; anchorItem: button; owner: nativeWidget
                contentWidth: 1120; contentHeight: 680
                // Remains closed: geometry bindings can be checked without
                // mapping this full-screen keyboard/dismissal overlay.
            }
            PanelUi.PopupStyler { id: nativeStyle; rootObject: nativeWidget; label: "spacing-fixture" }
        }
    }
    function windowFor(surface, side) {
        return side === "left" ? surface : input.findChild(surface, "rightEdgeWindow");
    }
    function enter(surface, side, y) {
        var window = windowFor(surface, side);
        input.mouseMove(window.contentItem, side === "left" ? 0 : window.width - 1, y);
    }
    function leave(surface, side) {
        var window = windowFor(surface, side);
        input.mouseMove(window.contentItem, -1, 100);
        input.wait(10);
        check(surface.edgeSide === "", "Edge hover did not clear on departure");
    }
    function open(surface, side, y) {
        enter(surface, side, y);
        input.wait(20);
        check(surface.edgeSide === side, "Edge handler covered: " + surface.screen.name + ":" + side);
        check(handoff.candidate === surface && handoff.dwellPending, "Edge did not start dwell");
        check(!surface.shown, "Opened before dwell finished");
        input.wait(280);
        check(surface.shown && surface.dockSide === side && surface.revealProgress === 1, "Edge failed to reveal");
    }
    function close(surface, side) {
        leave(surface, side);
        input.wait(200);
        check(!surface.shown && surface.revealProgress === 0, "Dock failed to hide");
    }
    function scrollIcons(surface, side) {
        var window = windowFor(surface, side);
        var x = side === "left" ? surface.dockWidth / 2 : window.width - surface.dockWidth / 2;
        var y = surface.dockTop + 18 + surface.viewportHeight / 2;
        input.mouseMove(window.contentItem, x, y);
        input.mouseWheel(window.contentItem, x, y, 0, -120, Qt.NoButton, Qt.NoModifier, 0);
        input.wait(50);
        var state = surface.stateSnapshot().scroll;
        check(state.overflowing && state.maximum === 22 && state.y > 0,
            "Actual dock did not scroll on " + side);
        for (var i = 0; i < 100 && surface.stateSnapshot().scroll.animating; i++) input.wait(20);
        check(Math.abs(surface.stateSnapshot().scroll.y - 22) < 0.2, "Actual dock did not rebound to bottom");
        input.mouseWheel(window.contentItem, x, y, 0, 120, Qt.NoButton, Qt.NoModifier, 0);
        for (var i = 0; i < 100 && surface.stateSnapshot().scroll.animating; i++) input.wait(20);
        check(Math.abs(surface.stateSnapshot().scroll.y) < 0.2, "Actual dock did not rebound to top");
    }
    function powerMenu(surface, side) {
        var window = windowFor(surface, side);
        var x = side === "left" ? surface.dockWidth / 2 : window.width - surface.dockWidth / 2;
        input.mouseClick(window.contentItem, x, surface.stateSnapshot().powerY);
        input.wait(400);
        var state = surface.stateSnapshot().powerMenu;
        var popup = input.findChild(surface, "powerPopup");
        check(state.opened && state.progress === 1 && state.fromRight === (side === "right"),
              "Power capsule did not open on " + side);
        check(popup.anchor.window === window && state.width === popup.implicitWidth && state.height === popup.implicitHeight,
              "Power capsule has the wrong anchor or dimensions");
        leave(surface, side);
        input.wait(150);
        check(surface.shown && surface.popupHeld, "Dock hid under an open power capsule");
        surface.close();
        for (var i = 0; i < 100 && (popup.visible || surface.shown || surface.revealProgress > 0); i++) input.wait(10);
        check(!popup.visible && !surface.shown && !surface.popupHeld,
              "Power capsule did not close and release the dock: " + JSON.stringify({
                  visible: popup.visible, opened: popup.open, reveal: surface.stateSnapshot().powerMenu.progress,
                  shown: surface.shown, held: surface.popupHeld, hover: surface.pointerHovered,
                  edge: surface.edgeSide, timer: surface.stateSnapshot().hidePending}));
    }
    function popupSpacing(surface, side) {
        var window = windowFor(surface, side);
        testHost.position = side;
        root.referenceWindow = window;
        var widget = nativeWidgetFactory.createObject(window.contentItem);
        input.wait(80);
        check(widget && widget.styler.cards.length === 2, "Native popup frames were not discovered");
        for (var record of widget.styler.cards) {
            check(record.positioning && record.positioning.snapshot().gap === PanelUi.PopupAppearance.horizontalGap,
                  "Native frame gap differs from tooltip on " + side);
        }
        function checkEdge() {
            var record = widget.styler.cards.find(item => item.window === widget.popup);
            var popupWindow = record.card.Window.window;
            var tooltipWindow = tooltipReference.contentItem.Window.window;
            var difference = side === "left" ? popupWindow.x - tooltipWindow.x
                : popupWindow.x + popupWindow.width - tooltipWindow.x - tooltipWindow.width;
            check(Math.abs(difference) < 0.01, "Mapped popup edge differs from tooltip on " + side + ": " + difference);
            var layerRecord = widget.styler.cards.find(item => item.window === widget.panel);
            var tooltipEdge = tooltipWindow.x - window.contentItem.Window.window.x;
            if (side === "right") tooltipEdge += tooltipWindow.width + widget.panel.screenW - window.width;
            var layerEdge = layerRecord.card.x + (side === "right" ? layerRecord.card.width : 0);
            check(Math.abs(layerEdge - tooltipEdge) < 0.01,
                  "Keyboard-panel edge differs from tooltip on " + side + ": " + (layerEdge - tooltipEdge));
            check(record.positioning.snapshot().gap === PanelUi.PopupAppearance.horizontalGap,
                  "Native anchoring overwrote the unified gap");
        }
        for (var repeat = 0; repeat < 3; repeat++) {
            widget.popup.open = true;
            input.wait(120);
            checkEdge();
            widget.popup.contentWidth += 30;
            input.wait(120);
            checkEdge();
            widget.popup.open = false;
            input.wait(30);
        }
        widget.destroy();
        root.referenceWindow = null;
        input.wait(30);
    }
    Timer {
        interval: 5; running: true; repeat: true
        onTriggered: if (testHost.surfaces.filter(item => item.revealProgress > 0).length > 1)
            root.failure = "Dock animations overlapped across screens";
    }
    Timer {
        interval: 400; running: true
        onTriggered: {
            try {
                check(testHost.surfaces.length > 0, "No screens");
                for (var i = 0; i < testHost.surfaces.length; i++) {
                    var surface = testHost.surfaces[i];
                    for (var side of ["left", "right"]) {
                        // Reopening the same edge after the scene has moved
                        // here catches the right-edge version of the bug too.
                        for (var repeat = 0; repeat < 2; repeat++) {
                            open(surface, side, Math.floor(surface.height / 2));
                            if (i === 0 && repeat === 0) scrollIcons(surface, side);
                            if (i === 0 && repeat === 0) popupSpacing(surface, side);
                            if (repeat === 0) powerMenu(surface, side);
                            else close(surface, side);
                        }
                    }
                }
                var first = testHost.surfaces[0];
                for (var side of ["left", "right"]) {
                    for (var y of [1, first.height - 1]) {
                        open(first, side, y);
                        close(first, side);
                    }
                }
                enter(first, "left", 100);
                input.wait(20);
                leave(first, "left");
                input.wait(280);
                check(!first.shown && !handoff.candidate, "Brief edge visit was not cancelled");

                if (testHost.surfaces.length > 1) {
                    var second = testHost.surfaces[1];
                    open(first, "left", 100);
                    leave(first, "left");
                    enter(second, "right", 100);
                    input.wait(20);
                    check(!first.shown && first.revealProgress > 0 && !second.shown,
                        "Cross-screen handoff did not close before opening");
                    input.wait(280);
                    check(first.revealProgress === 0 && second.shown && second.onRight,
                        "Cross-screen edge reveal failed");
                    close(second, "right");
                }
                check(!failure, failure);
                console.log("EDGES_PASS", testHost.surfaces.length + " screens: native popup/keyboard-panel spacing matches tooltip on both sides, repeated resize/reopen, power menu, elastic scrolling and cross-screen handoff passed");
            } catch (error) { console.log("EDGES_FAIL", String(error)); }
            Qt.quit();
        }
    }
}
