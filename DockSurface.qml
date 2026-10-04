import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "SidePanelModel.js" as Model
import "UsageModel.js" as Usage
import "Ui" as PanelUi

PanelWindow {
    id: surface
    required property var host
    property bool onRight: false
    readonly property string dockSide: onRight ? "right" : "left"
    readonly property var dockOwner: surface
    readonly property var currentWindow: onRight ? rightWindow : surface
    readonly property string edgeSide: rightTriggerHover.hovered ? "right" : leftTriggerHover.hovered ? "left" : ""
    readonly property bool pointerHovered: pointerHover.hovered || leftTriggerHover.hovered || rightTriggerHover.hovered
    readonly property string pendingSide: host.dockCoordinator.candidate === surface ? host.dockCoordinator.candidateSide : ""
    property bool revealed: false
    property real pointerY: -10000
    readonly property real baseScale: host.options.iconSize / Style.bar.iconCanvas
    readonly property real dockWidth: Math.ceil(host.barSize * baseScale + 18)
    readonly property real viewportHeight: Math.min(column.implicitHeight, Math.max(100, height - 80))
    readonly property real dockHeight: viewportHeight + 36
    readonly property real dockTop: Math.round((height - dockHeight) / 2)
    readonly property real triggerHeight: height
    readonly property real triggerTop: 0
    readonly property bool popupHeld: host.activePopout && host.targetBelongsToWindow(host.activePopout, surface)
    readonly property bool shown: !host.barHidden && (revealed || popupHeld)
    property real revealProgress: shown ? 1 : 0
    color: "transparent"
    surfaceFormat.opaque: false
    implicitWidth: Math.ceil(dockWidth * host.options.magnification + host.options.hideDistance)
    // These two windows never change screen or horizontal anchors. Only the
    // invisible dock content changes visual parent before it starts opening.
    anchors { left: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    visible: !remapGuard.remapping
    WlrLayershell.namespace: "omarchy-side-panel"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Behavior on revealProgress {
        NumberAnimation { duration: surface.host.options.animationDuration; easing.type: Easing.OutCubic }
    }
    ScreenMoveRemap { id: remapGuard; window: surface }

    // Each edge remains mapped at a fixed position, with a 2px input strip.
    mask: Region {
        Region {
            y: surface.triggerTop
            width: surface.host.barHidden ? 0 : surface.host.options.triggerWidth
            height: surface.triggerHeight
        }
        Region {
            y: Math.max(0, surface.dockTop - surface.host.options.hideDistance)
            width: surface.shown && !surface.onRight ? surface.dockWidth + surface.host.options.hideDistance : 0
            height: surface.dockHeight + surface.host.options.hideDistance * 2
        }
    }

    function close() { powerPopup.open = false; }
    function stateSnapshot() {
        return {name: screen ? screen.name : "", side: dockSide, shown: shown,
            progress: Number(revealProgress.toFixed(3)), popupHeld: !!popupHeld,
            pointerY: pointerY, pointerHovered: pointerHovered,
            triggerHovered: onRight ? rightTriggerHover.hovered : leftTriggerHover.hovered,
            oppositeHovered: onRight ? leftTriggerHover.hovered : rightTriggerHover.hovered,
            hidePending: hideTimer.running,
            showPending: pendingSide !== "" && host.dockCoordinator.dwellPending,
            pendingSide: pendingSide, showDelay: host.options.showDelay,
            triggerEdges: ["left", "right"],
            triggerTop: triggerTop, triggerHeight: triggerHeight,
            dockTop: dockTop, dockHeight: dockHeight, dockWidth: dockWidth,
            contentHeight: column.implicitHeight, viewportHeight: viewportHeight,
            scroll: {y: Number(flick.contentY.toFixed(3)), maximum: flick.maximumY,
                overflowing: flick.overflowing, animating: flick.wheelAnimating},
            powerMenu: powerCapsule.snapshot(),
            powerY: dockTop + 18 + powerCell.y + powerCell.height / 2 - flick.contentY,
            powerNormalization: powerIcon.iconNormalizer.snapshot(),
            powerVectors: powerIcon.iconRasterizer.glyphSnapshot(),
            icons: column.orderedCells.map(function(cell) {
                return {key: cell.usageKey, clicks: surface.host.iconClickCount(cell.usageKey),
                    y: surface.dockTop + 18 + cell.y + cell.height / 2 - flick.contentY,
                    tray: cell.trayButton ? cell.trayButton.iconRasterizer.snapshot() : null,
                    normalization: cell.trayButton ? cell.trayButton.iconNormalizer.snapshot() : null};
            }),
            actions: Array.from({length: actions.count}, function(_, index) {
                var cell = actions.itemAt(index);
                return cell ? {id: cell.modelData, y: dockTop + 18 + cell.y + cell.height / 2 - flick.contentY,
                    scale: cell.iconScale, normalization: cell.children[0].iconNormalizer.snapshot(),
                    vectorGlyphs: cell.children[0].iconRasterizer.glyphSnapshot()} : null;
            })};
    }
    Component.onCompleted: host.registerSurface(surface)
    Component.onDestruction: host.unregisterSurface(surface)
    onShownChanged: {
        updateHoverTimers();
        if (!shown) host.clearTooltip();
    }
    onRevealProgressChanged: {
        if (revealProgress === 0) {
            host.refreshIconOrder();
            host.dockCoordinator.advance();
        }
    }
    function revealAt(side) {
        if (shown || revealProgress > 0) return;
        onRight = side === "right";
        revealed = true;
        hideTimer.stop();
    }
    function updateHoverTimers() {
        if (edgeSide && !host.barHidden) host.dockCoordinator.request(surface, edgeSide);
        else host.dockCoordinator.cancel(surface);
        if (pointerHovered || popupHeld) hideTimer.stop();
        else hideTimer.restart();
    }
    onEdgeSideChanged: updateHoverTimers()

    Timer {
        id: hideTimer
        interval: surface.host.options.hideDelay
        onTriggered: if (!surface.pointerHovered && !surface.popupHeld) surface.revealed = false
    }
    onPopupHeldChanged: {
        updateHoverTimers();
    }
    // Hover signal handlers can run before this combined binding updates.
    // Re-evaluate departure after its new value has been committed.
    onPointerHoveredChanged: updateHoverTimers()
    Connections {
        target: surface.host
        function onBarHiddenChanged() {
            if (surface.host.barHidden) {
                surface.host.dockCoordinator.cancel(surface);
                surface.revealed = false;
            }
        }
    }

    Item {
        x: 0
        y: surface.triggerTop
        width: surface.host.options.triggerWidth
        height: surface.triggerHeight
        // The full-window scene is stacked above earlier siblings, including
        // after it is reparented here. Keep the edge first in hover delivery.
        z: 1
        HoverHandler { id: leftTriggerHover; blocking: false }
    }

    Item {
        id: scene
        parent: surface.currentWindow.contentItem
        anchors.fill: parent
        clip: true
        HoverHandler {
            id: pointerHover
            onHoveredChanged: surface.updateHoverTimers()
            onPointChanged: if (hovered) surface.pointerY = point.position.y
        }

        Item {
            id: dock
            width: surface.dockWidth
            height: surface.dockHeight
            y: surface.dockTop
            x: surface.onRight ? surface.width - width + (1 - surface.revealProgress) * (width + 8)
                : (surface.revealProgress - 1) * (width + 8)
            opacity: Math.min(1, surface.revealProgress * 2)

            Canvas {
                id: chrome
                anchors.fill: parent
                antialiasing: true
                property color fillColor: Qt.rgba(surface.host.background.r, surface.host.background.g, surface.host.background.b, 1)
                onFillColorChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                property bool mirrored: surface.onRight
                onMirroredChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    var w = width, h = height, r = 18;
                    ctx.reset();
                    if (mirrored) { ctx.translate(w, 0); ctx.scale(-1, 1); }
                    ctx.beginPath();
                    ctx.moveTo(0, 0);
                    ctx.bezierCurveTo(0, r, w, 0, w, r * 1.5);
                    ctx.lineTo(w, h - r * 1.5);
                    ctx.bezierCurveTo(w, h, 0, h - r, 0, h);
                    ctx.closePath();
                    ctx.fillStyle = fillColor;
                    ctx.fill();
                    ctx.strokeStyle = Qt.rgba(surface.host.foreground.r, surface.host.foreground.g, surface.host.foreground.b, 0.12);
                    ctx.lineWidth = 1;
                    ctx.stroke();
                }
                Connections { target: surface.host; function onForegroundChanged() { chrome.requestPaint(); } }
            }

            PanelUi.ElasticFlickable {
                id: flick
                x: 0
                y: 18
                width: parent.width
                height: surface.viewportHeight
                contentHeight: column.implicitHeight
                wheelScrollingEnabled: surface.shown && !surface.popupHeld
                wheelStep: Math.ceil(Style.bar.iconSlot * surface.baseScale + 6)
                onContentYChanged: surface.host.clearTooltip()

                DockLayout {
                    id: column
                    width: flick.width
                    counts: surface.host.orderCounts

                    DockCell {
                        id: powerCell
                        usageKey: "action:power"
                        ordinal: 0
                        nativeHeight: powerIcon.implicitHeight
                        ActionIcon {
                            id: powerIcon
                            host: surface.host
                            action: "power"
                            anchors.centerIn: parent
                            width: implicitWidth
                            height: implicitHeight
                            scale: powerCell.iconScale
                            onPressed: function(button) { if (button === Qt.LeftButton) powerPopup.open = !powerPopup.open; }
                        }
                    }

                    Repeater {
                        model: surface.host.rightEntries
                        delegate: Item {
                            id: group
                            required property var modelData
                            required property int index
                            width: column.width
                            height: column.height
                            DockCell {
                                id: cell
                                usageKey: "widget:" + widget.moduleName
                                ordinal: (group.index + 1) * 100000
                                nativeHeight: widget.naturalHeight
                                WidgetSlot {
                                    id: widget
                                    host: surface.host
                                    entry: group.modelData
                                    anchors.centerIn: parent
                                    scale: cell.iconScale
                                }
                            }
                            Repeater {
                                model: widget.trayItems
                                delegate: DockCell {
                                    id: trayCell
                                    required property var modelData
                                    required property int index
                                    usageKey: Usage.trayKey(modelData)
                                    ordinal: (group.index + 1) * 100000 + index + 1
                                    nativeHeight: trayIcon.implicitHeight
                                    trayButton: trayIcon
                                    TrayButton {
                                        id: trayIcon
                                        host: surface.host
                                        controller: widget.activeItem
                                        modelData: trayCell.modelData
                                        anchors.centerIn: parent
                                        scale: trayCell.iconScale
                                    }
                                }
                            }
                        }
                    }

                    Repeater {
                        id: actions
                        model: ["recording", "idle", "notifications", "reload"]
                        delegate: DockCell {
                            id: actionCell
                            required property string modelData
                            required property int index
                            usageKey: "action:" + modelData
                            ordinal: (surface.host.rightEntries.length + 1) * 100000 + index
                            nativeHeight: actionIcon.implicitHeight
                            ActionIcon {
                                id: actionIcon
                                host: surface.host
                                action: actionCell.modelData
                                anchors.centerIn: parent
                                width: implicitWidth
                                height: implicitHeight
                                scale: actionCell.iconScale
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: flick.contentHeight > flick.height && flick.contentY > 2
                x: parent.width - 4; y: 24; width: 2; height: 14; radius: 1
                color: surface.host.foreground; opacity: 0.4
            }
            Rectangle {
                visible: flick.contentHeight > flick.height && flick.contentY < flick.contentHeight - flick.height - 2
                x: parent.width - 4; y: parent.height - 38; width: 2; height: 14; radius: 1
                color: surface.host.foreground; opacity: 0.4
            }
        }
    }

    PanelWindow {
        id: rightWindow
        readonly property var dockOwner: surface
        readonly property string dockSide: "right"
        screen: surface.screen
        implicitWidth: surface.implicitWidth
        anchors { right: true; top: true; bottom: true }
        color: "transparent"
        surfaceFormat.opaque: false
        exclusionMode: ExclusionMode.Ignore
        visible: !rightRemap.remapping
        WlrLayershell.namespace: "omarchy-side-panel-right"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        ScreenMoveRemap { id: rightRemap; window: rightWindow }
        mask: Region {
            Region {
                x: rightWindow.width - surface.host.options.triggerWidth
                width: surface.host.barHidden ? 0 : surface.host.options.triggerWidth
                height: surface.triggerHeight
            }
            Region {
                x: rightWindow.width - surface.dockWidth - surface.host.options.hideDistance
                y: Math.max(0, surface.dockTop - surface.host.options.hideDistance)
                width: surface.shown && surface.onRight ? surface.dockWidth + surface.host.options.hideDistance : 0
                height: surface.dockHeight + surface.host.options.hideDistance * 2
            }
        }
        Item {
            x: rightWindow.width - width
            width: surface.host.options.triggerWidth
            height: surface.triggerHeight
            z: 1
            HoverHandler { id: rightTriggerHover; blocking: false }
        }
    }

    component DockCell: Item {
        id: dockCell
        property string usageKey: ""
        property int ordinal: 0
        property var trayButton: null
        property real nativeHeight: 27
        readonly property real centerY: surface.dockTop + 18 + y + height / 2 - flick.contentY
        readonly property real proximityScale: pointerHover.hovered && !surface.popupHeld
            ? Model.magnification(surface.pointerY, centerY, 100, surface.host.options.magnification) : 1
        property real iconScale: surface.baseScale * proximityScale
        width: column.width
        height: nativeHeight > 0 ? Math.ceil(nativeHeight * surface.baseScale + 2) : 0
        y: column.cellY(dockCell)
        Component.onCompleted: column.registerCell(dockCell)
        Component.onDestruction: column.unregisterCell(dockCell)
        Behavior on iconScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    PopupWindow {
        id: powerPopup
        property bool open: false
        visible: open || powerCapsule.reveal > 0
        color: "transparent"
        implicitWidth: powerCapsule.implicitWidth
        implicitHeight: powerCapsule.implicitHeight
        onOpenChanged: {
            if (open) surface.host.requestPopout(surface);
            else surface.host.releasePopout(surface);
        }
        HyprlandFocusGrab {
            active: powerPopup.open
            windows: [powerPopup, surface.currentWindow]
            onCleared: surface.close()
        }
        anchor {
            window: surface.currentWindow
            adjustment: PopupAdjustment.Slide
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | (surface.onRight ? Edges.Left : Edges.Right)
            rect.width: 1
            rect.height: 1
            rect.x: surface.onRight ? surface.width - surface.dockWidth - PanelUi.PopupAppearance.horizontalGap
                : surface.dockWidth + PanelUi.PopupAppearance.horizontalGap
            rect.y: Math.round(Math.max(12, Math.min(
                surface.dockTop + 18 + powerCell.y + powerCell.height / 2 - flick.contentY - powerPopup.implicitHeight / 2,
                surface.height - powerPopup.implicitHeight - 12)))
        }
        PanelUi.PowerCapsule {
            id: powerCapsule
            anchors.fill: parent
            opened: powerPopup.open
            fromRight: surface.onRight
            fontFamily: PanelUi.PopupAppearance.fontFamily
            originY: surface.dockTop + 18 + powerCell.y + powerCell.height / 2 - flick.contentY - powerPopup.anchor.rect.y
            onActionTriggered: function(command) {
                powerPopup.open = false;
                Quickshell.execDetached(["omarchy", "system", command]);
            }
        }
    }

    PopupWindow {
        id: tooltip
        visible: surface.host.tooltipShown && surface.host.targetBelongsToWindow(surface.host.tooltipTarget, surface)
        color: "transparent"
        mask: Region {}
        implicitWidth: label.implicitWidth + PanelUi.PopupAppearance.horizontalPadding * 2
        implicitHeight: label.implicitHeight + PanelUi.PopupAppearance.verticalPadding * 2
        anchor {
            window: surface.currentWindow
            adjustment: PopupAdjustment.Slide
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | (surface.onRight ? Edges.Left : Edges.Right)
            rect.width: 1
            rect.height: 1
            rect.x: surface.onRight ? surface.width - surface.dockWidth - PanelUi.PopupAppearance.horizontalGap
                : surface.dockWidth + PanelUi.PopupAppearance.horizontalGap
            rect.y: {
                var target = surface.host.tooltipTarget;
                if (!target || !surface.host.targetBelongsToWindow(target, surface)) return 0;
                return Math.round(surface.currentWindow.contentItem.mapFromItem(target, 0, target.height / 2).y - tooltip.implicitHeight / 2);
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: PanelUi.PopupAppearance.radius
            color: PanelUi.PopupAppearance.background
            border.color: PanelUi.PopupAppearance.borderColor
            border.width: PanelUi.PopupAppearance.borderWidth
            Text {
                id: label
                anchors.centerIn: parent
                text: surface.host.tooltipText
                textFormat: Text.PlainText
                color: PanelUi.PopupAppearance.foreground
                font.family: PanelUi.PopupAppearance.fontFamily
                font.pixelSize: PanelUi.PopupAppearance.fontSize
            }
        }
    }
}
