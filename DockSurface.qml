import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "SidePanelModel.js" as Model
import "Ui" as PanelUi

PanelWindow {
    id: surface
    required property var host
    property bool revealed: false
    property real pointerY: -10000
    readonly property real baseScale: host.options.iconSize / Style.bar.iconCanvas
    readonly property real dockWidth: Math.ceil(host.barSize * baseScale + 18)
    readonly property real viewportHeight: Math.min(column.implicitHeight, Math.max(100, height - 80))
    readonly property real dockHeight: viewportHeight + 36
    readonly property real dockTop: Math.round((height - dockHeight) / 2)
    readonly property real triggerHeight: Math.min(height, host.options.triggerHeight)
    readonly property real triggerTop: Math.round((height - triggerHeight) / 2)
    readonly property bool popupHeld: host.activePopout && host.targetBelongsToWindow(host.activePopout, surface)
    readonly property bool shown: !host.barHidden && (revealed || popupHeld)
    property real revealProgress: shown ? 1 : 0
    color: "transparent"
    surfaceFormat.opaque: false
    implicitWidth: Math.ceil(dockWidth * host.options.magnification + host.options.hideDistance)
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

    // Only a short, centered strip receives input while hidden. Once shown,
    // the whole dock and its departure gutter become interactive.
    mask: Region {
        Region {
            x: 0
            y: surface.triggerTop
            width: surface.host.barHidden ? 0 : surface.host.options.triggerWidth
            height: surface.triggerHeight
        }
        Region {
            x: 0
            y: Math.max(0, surface.dockTop - surface.host.options.hideDistance)
            width: surface.shown ? surface.dockWidth + surface.host.options.hideDistance : 0
            height: surface.dockHeight + surface.host.options.hideDistance * 2
        }
    }

    function close() { powerPopup.open = false; }
    function stateSnapshot() {
        return {name: screen ? screen.name : "", shown: shown,
            progress: Number(revealProgress.toFixed(3)), popupHeld: !!popupHeld,
            pointerY: pointerY,
            showPending: showTimer.running, showDelay: host.options.showDelay,
            triggerTop: triggerTop, triggerHeight: triggerHeight,
            dockTop: dockTop, dockHeight: dockHeight, dockWidth: dockWidth,
            contentHeight: column.implicitHeight, viewportHeight: viewportHeight,
            powerY: dockTop + 18 + powerCell.height / 2 - flick.contentY,
            powerNormalization: powerIcon.iconNormalizer.snapshot(),
            actions: [0, 1, 2].map(function(index) {
                var cell = actions.itemAt(index);
                return cell ? {id: cell.modelData, y: dockTop + 18 + cell.y + cell.height / 2 - flick.contentY,
                    scale: cell.iconScale, normalization: cell.children[0].iconNormalizer.snapshot()} : null;
            })};
    }
    Component.onCompleted: host.registerSurface(surface)
    Component.onDestruction: host.unregisterSurface(surface)
    onShownChanged: {
        if (shown) showTimer.stop();
        else host.clearTooltip();
    }

    Timer {
        id: showTimer
        interval: surface.host.options.showDelay
        onTriggered: {
            if (triggerHover.hovered && !surface.host.barHidden && !surface.shown)
                surface.revealed = true;
        }
    }

    Timer {
        id: hideTimer
        interval: surface.host.options.hideDelay
        onTriggered: if (!pointerHover.hovered && !surface.popupHeld) surface.revealed = false
    }
    onPopupHeldChanged: {
        if (popupHeld) hideTimer.stop();
        else if (!pointerHover.hovered) hideTimer.restart();
    }
    Connections {
        target: surface.host
        function onBarHiddenChanged() {
            if (surface.host.barHidden) {
                showTimer.stop();
                surface.revealed = false;
            }
        }
    }

    Item {
        id: scene
        anchors.fill: parent
        clip: true
        HoverHandler {
            id: pointerHover
            onHoveredChanged: {
                if (hovered) hideTimer.stop();
                else {
                    showTimer.stop();
                    hideTimer.restart();
                }
            }
            onPointChanged: if (hovered) surface.pointerY = point.position.y
        }

        Item {
            x: 0
            y: surface.triggerTop
            width: surface.host.options.triggerWidth
            height: surface.triggerHeight
            HoverHandler {
                id: triggerHover
                onHoveredChanged: {
                    if (hovered && !surface.shown && !surface.host.barHidden)
                        showTimer.restart();
                    else showTimer.stop();
                }
            }
        }

        Item {
            id: dock
            width: surface.dockWidth
            height: surface.dockHeight
            y: surface.dockTop
            x: (surface.revealProgress - 1) * (width + 8)
            opacity: Math.min(1, surface.revealProgress * 2)

            Canvas {
                id: chrome
                anchors.fill: parent
                antialiasing: true
                property color fillColor: Qt.rgba(surface.host.background.r, surface.host.background.g, surface.host.background.b, 1)
                onFillColorChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    var w = width, h = height, r = 18;
                    ctx.reset();
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

            Flickable {
                id: flick
                x: 0
                y: 18
                width: parent.width
                height: surface.viewportHeight
                contentWidth: width
                contentHeight: column.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: column
                    width: flick.width
                    spacing: 4

                    DockCell {
                        id: powerCell
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

                    Separator {}

                    Repeater {
                        model: surface.host.rightEntries
                        delegate: DockCell {
                            id: cell
                            required property var modelData
                            nativeHeight: widget.naturalHeight
                            WidgetSlot {
                                id: widget
                                host: surface.host
                                entry: cell.modelData
                                anchors.centerIn: parent
                                scale: cell.iconScale
                            }
                        }
                    }

                    Separator {}

                    Repeater {
                        id: actions
                        model: ["recording", "idle", "notifications"]
                        delegate: DockCell {
                            id: actionCell
                            required property string modelData
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

    component DockCell: Item {
        property real nativeHeight: 27
        readonly property real centerY: surface.dockTop + 18 + y + height / 2 - flick.contentY
        readonly property real proximityScale: pointerHover.hovered && !surface.popupHeld
            ? Model.magnification(surface.pointerY, centerY, 100, surface.host.options.magnification) : 1
        property real iconScale: surface.baseScale * proximityScale
        width: column.width
        height: nativeHeight > 0 ? Math.ceil(nativeHeight * surface.baseScale + 2) : 0
        Behavior on iconScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
    component Separator: Rectangle {
        width: column.width - 24
        height: 1
        anchors.horizontalCenter: parent.horizontalCenter
        color: surface.host.foreground
        opacity: 0.14
    }

    PopupWindow {
        id: powerPopup
        property bool open: false
        visible: open || powerCard.opacity > 0
        color: "transparent"
        implicitWidth: 244
        implicitHeight: 90
        onOpenChanged: {
            if (open) surface.host.requestPopout(surface);
            else surface.host.releasePopout(surface);
        }
        HyprlandFocusGrab {
            active: powerPopup.open
            windows: [powerPopup, surface]
            onCleared: surface.close()
        }
        anchor {
            window: surface
            adjustment: PopupAdjustment.Slide
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
            rect.width: 1
            rect.height: 1
            rect.x: surface.dockWidth + 10
            rect.y: Math.round(Math.max(12, Math.min(
                surface.dockTop + 18 + powerCell.height / 2 - flick.contentY - powerPopup.implicitHeight / 2,
                surface.height - powerPopup.implicitHeight - 12)))
        }
        Rectangle {
            id: powerCard
            anchors.fill: parent
            radius: PanelUi.PopupAppearance.radius
            color: PanelUi.PopupAppearance.background
            border.color: PanelUi.PopupAppearance.borderColor
            border.width: PanelUi.PopupAppearance.borderWidth
            opacity: powerPopup.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
        Row {
            anchors.centerIn: parent
            opacity: powerCard.opacity
            spacing: 6
            Repeater {
                model: [
                    {label: "关机", icon: "󰐥", command: "shutdown"},
                    {label: "注销", icon: "󰍃", command: "logout"},
                    {label: "重启", icon: "󰑓", command: "reboot"}
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: 68; height: 64; radius: PanelUi.PopupAppearance.radius
                    color: buttonMouse.containsMouse ? Qt.rgba(surface.host.foreground.r, surface.host.foreground.g, surface.host.foreground.b, 0.1) : "transparent"
                    Column {
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.icon
                            color: PanelUi.PopupAppearance.foreground
                            font.family: PanelUi.PopupAppearance.fontFamily
                            font.pixelSize: 27
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            color: PanelUi.PopupAppearance.foreground
                            font.family: PanelUi.PopupAppearance.fontFamily
                            font.pixelSize: PanelUi.PopupAppearance.fontSize
                        }
                    }
                    MouseArea {
                        id: buttonMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerPopup.open = false;
                            Quickshell.execDetached(["omarchy", "system", modelData.command]);
                        }
                    }
                }
            }
        }
    }

    PanelUi.PopupStyler { id: powerStyler; rootObject: powerCard; label: "power" }

    PopupWindow {
        id: tooltip
        visible: surface.host.tooltipShown && surface.host.targetBelongsToWindow(surface.host.tooltipTarget, surface)
        color: "transparent"
        mask: Region {}
        implicitWidth: label.implicitWidth + PanelUi.PopupAppearance.horizontalPadding * 2
        implicitHeight: label.implicitHeight + PanelUi.PopupAppearance.verticalPadding * 2
        anchor {
            window: surface
            adjustment: PopupAdjustment.Slide
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
            rect.width: 1
            rect.height: 1
            rect.x: surface.dockWidth + 10
            rect.y: {
                var target = surface.host.tooltipTarget;
                if (!target || !surface.host.targetBelongsToWindow(target, surface)) return 0;
                return Math.round(surface.contentItem.mapFromItem(target, 0, target.height / 2).y - tooltip.implicitHeight / 2);
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
