import QtQuick
import Quickshell

// Keep native popup lifecycle and vertical placement. Only the horizontal
// frame position follows the same visible dock edge as its tooltip.
Item {
    id: positioner
    property var window: null
    property var card: null
    readonly property var sourceItem: window && "anchorItem" in window ? window.anchorItem : null
    readonly property var sourceWindow: sourceItem ? sourceItem.QsWindow.window : null
    readonly property var dock: sourceWindow && "dockOwner" in sourceWindow ? sourceWindow.dockOwner : null
    readonly property bool active: PopupAppearance.enabled && !!dock && !!card && (layerPanel || !!popupAnchor)
    readonly property bool layerPanel: window && "cardOrigin" in window
    readonly property var popupAnchor: window && "anchor" in window ? window.anchor : null
    readonly property real anchorX: dock ? (dock.onRight
        ? sourceWindow.width - dock.dockWidth - PopupAppearance.horizontalGap
        : dock.dockWidth + PopupAppearance.horizontalGap) : 0
    readonly property real layerX: active && layerPanel ? (dock.onRight
        ? window.screenW - dock.dockWidth - PopupAppearance.horizontalGap - card.width
        : dock.dockWidth + PopupAppearance.horizontalGap) : 0

    Binding {
        target: positioner.card
        property: "x"
        value: positioner.layerX
        when: positioner.active && positioner.layerPanel
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: positioner.popupAnchor
        property: "gravity"
        value: Edges.Bottom | (positioner.dock && positioner.dock.onRight ? Edges.Left : Edges.Right)
        when: positioner.active && !positioner.layerPanel && !!positioner.popupAnchor
        restoreMode: Binding.RestoreBindingOrValue
    }
    function alignAnchor() {
        if (active && !layerPanel && popupAnchor) popupAnchor.rect.x = anchorX;
    }
    onActiveChanged: alignAnchor()
    onAnchorXChanged: alignAnchor()
    Connections {
        target: positioner.popupAnchor
        enabled: positioner.active && !positioner.layerPanel
        ignoreUnknownSignals: true
        // PopupCard computes its native Y here. Our handler then aligns X.
        function onAnchoring() { positioner.alignAnchor(); }
    }
    Connections {
        target: positioner.window
        ignoreUnknownSignals: true
        function onVisibleChanged() { positioner.alignAnchor(); }
    }
    function snapshot() {
        if (!active) return null;
        return {side: dock.dockSide, mode: layerPanel ? "panel" : "popup",
            gap: layerPanel ? Number((dock.onRight
                ? window.screenW - dock.dockWidth - card.x - card.width : card.x - dock.dockWidth).toFixed(3))
                : Number((dock.onRight ? sourceWindow.width - dock.dockWidth - popupAnchor.rect.x
                    : popupAnchor.rect.x - dock.dockWidth).toFixed(3))};
    }
}
