import QtQuick
import "IconGeometry.js" as Geometry

// Measure only on visual changes. The layer crop leaves hit areas untouched.
Item {
    id: normalizer
    readonly property bool sidePanelIconNormalizer: true
    property var sourceItem: null
    property bool normalize: true
    property real targetSize: 16
    property var bounds: null
    property var grabResult: null
    property bool busy: false
    property int revision: 0
    property var watches: []
    property var watched: new WeakSet()
    readonly property var crop: Geometry.sourceRect(bounds,
        sourceItem ? sourceItem.width : 0, sourceItem ? sourceItem.height : 0, targetSize)
    readonly property rect sourceRect: normalize ? Qt.rect(crop.x, crop.y, crop.width, crop.height) : Qt.rect(0, 0, 0, 0)
    opacity: 0

    Component {
        id: visualWatch
        Connections {
            property var adapter
            ignoreUnknownSignals: true
            function onTextChanged() { adapter.schedule(); }
            function onSourceChanged() { adapter.schedule(); }
            function onStatusChanged() { adapter.schedule(); }
            function onVisibleChanged() { adapter.schedule(); }
            function onFontChanged() { adapter.schedule(); }
            function onFontSizeChanged() { adapter.schedule(); }
            function onWidthChanged() { adapter.schedule(); }
            function onHeightChanged() { adapter.schedule(); }
            function onChildrenChanged() { adapter.watchTree(); adapter.schedule(); }
        }
    }
    function watch(item) {
        if (!item || "sidePanelIconNormalizer" in item) return;
        if (!watched.has(item)) {
            watched.add(item);
            watches.push(visualWatch.createObject(normalizer, {target: item, adapter: normalizer}));
        }
        if ("children" in item) for (var i = 0; i < item.children.length; i++) watch(item.children[i]);
    }
    function watchTree() { watch(sourceItem); }
    function schedule() { revision++; captureTimer.restart(); }
    function capture() {
        if (busy || !normalize || !sourceItem || !sourceItem.visible || !probe.available
            || sourceItem.width <= 0 || sourceItem.height <= 0) return;
        var item = sourceItem, current = revision;
        var w = Math.max(1, Math.ceil(item.width * 2)), h = Math.max(1, Math.ceil(item.height * 2));
        busy = true;
        if (!item.grabToImage(function(result) {
            busy = false;
            if (normalizer.sourceItem !== item || current !== normalizer.revision) { normalizer.schedule(); return; }
            if (normalizer.grabResult) probe.unloadImage(normalizer.grabResult.url);
            normalizer.grabResult = result;
            probe.width = w; probe.height = h;
            probe.loadImage(result.url);
            probe.requestPaint();
        }, Qt.size(w, h))) busy = false;
    }
    function reset() {
        watches.forEach(function(watch) { if (watch) watch.destroy(); });
        watches = []; watched = new WeakSet(); bounds = null;
        Qt.callLater(function() { watchTree(); schedule(); });
    }
    function snapshot() {
        return {ready: !!bounds, bounds: bounds, targetSize: targetSize,
            sourceRect: {x: sourceRect.x, y: sourceRect.y, width: sourceRect.width, height: sourceRect.height}};
    }
    onSourceItemChanged: reset()
    onNormalizeChanged: schedule()
    Component.onCompleted: reset()
    Timer { id: captureTimer; interval: 20; onTriggered: normalizer.capture() }
    Canvas {
        id: probe
        width: 1; height: 1
        onAvailableChanged: if (available) normalizer.schedule()
        onImageLoaded: requestPaint()
        onPaint: {
            if (!normalizer.grabResult || !isImageLoaded(normalizer.grabResult.url) || !normalizer.sourceItem) return;
            var ctx = getContext("2d");
            ctx.reset(); ctx.drawImage(normalizer.grabResult.url, 0, 0, width, height);
            var found = Geometry.alphaBounds(ctx.getImageData(0, 0, width, height).data, width, height, 32);
            if (found) normalizer.bounds = {
                x: found.x * normalizer.sourceItem.width / width,
                y: found.y * normalizer.sourceItem.height / height,
                width: found.width * normalizer.sourceItem.width / width,
                height: found.height * normalizer.sourceItem.height / height};
        }
    }
}
