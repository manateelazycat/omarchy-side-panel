import QtQuick
import qs.Commons

// Replace icon paint with matching SVGs while retaining native interaction.
// Only walk visual children: separate menu windows keep their own UI.
Item {
    id: rasterizer
    property var rootItem: null
    property bool pixelated: true
    property int pixels: 16
    property var bindings: []
    property var watches: []
    property var images: []
    property var normalizers: []
    property var imageNormalizers: new WeakMap()
    property var vectors: []
    property var imageVectors: new WeakMap()
    property var adapted: new WeakMap()

    Component {
        id: propertyBinding
        Binding {
            id: overrideBinding
            required property var resolve
            value: overrideBinding.resolve()
            restoreMode: Binding.RestoreBindingOrValue
        }
    }
    Component {
        id: childWatch
        Connections {
            property var refresh: null
            ignoreUnknownSignals: true
            function onChildrenChanged() { if (refresh) Qt.callLater(refresh); }
        }
    }
    Component { id: iconNormalizer; IconNormalizer {} }
    Component { id: glyphVector; VectorGlyph {} }
    Component { id: trayVector; VectorTray {} }
    function bind(item, key, resolve) {
        bindings.push(propertyBinding.createObject(rasterizer,
            {target: item, property: key, resolve: resolve}));
    }
    function visit(item, seen) {
        if (!item || item === rasterizer || "sidePanelIconNormalizer" in item
            || "sidePanelVectorGlyph" in item || seen.has(item)) return;
        seen.add(item);
        if (!adapted.has(item)) {
            adapted.set(item, true);
            if ("sourceSize" in item && "fillMode" in item) {
                images.push(item);
                bind(item, "smooth", function() { return !rasterizer.pixelated; });
                bind(item, "mipmap", function() { return false; });
                bind(item, "sourceSize.width", function() { return 128; });
                bind(item, "sourceSize.height", function() { return 128; });
                var icon = item.parent;
                if (icon && "symbolic" in icon && "icon" in icon) {
                    bind(icon, "width", function() { return Style.bar.iconCanvas; });
                    bind(icon, "height", function() { return Style.bar.iconCanvas; });
                    var normalizer = iconNormalizer.createObject(rasterizer, {parent: rasterizer,
                        sourceItem: icon, targetSize: Style.bar.iconCanvas});
                    normalizers.push(normalizer);
                    imageNormalizers.set(item, normalizer);
                    var vector = trayVector.createObject(rasterizer, {parent: icon, sourceImage: item, trayIcon: icon});
                    vectors.push(vector); imageVectors.set(item, vector);
                    for (var effectIndex = 0; effectIndex < icon.children.length; effectIndex++) {
                        var effect = icon.children[effectIndex];
                        if ("colorization" in effect && "source" in effect && effect.source === item)
                            bind(effect, "opacity", function() { return vector.ready ? 0 : 1; });
                    }
                    bind(icon, "layer.enabled", function() { return true; });
                    bind(icon, "layer.sourceRect", function() { return normalizer.sourceRect; });
                    bind(icon, "layer.textureSize", function() {
                        return rasterizer.pixelated ? Qt.size(rasterizer.pixels, rasterizer.pixels) : Qt.size(128, 128);
                    });
                    bind(icon, "layer.smooth", function() { return !rasterizer.pixelated; });
                    bind(icon, "layer.mipmap", function() { return false; });
                }
            } else if ("font" in item && "text" in item && "baselineOffset" in item) {
                var glyph = glyphVector.createObject(rasterizer, {parent: item.parent, sourceText: item});
                vectors.push(glyph);
            } else if ("children" in item && !("font" in item) && !("radius" in item)) {
                watches.push(childWatch.createObject(rasterizer, {target: item,
                    refresh: function() { rasterizer.refresh(); }}));
            }
        }
        if ("children" in item) {
            for (var i = 0; i < item.children.length; i++) visit(item.children[i], seen);
        }
    }
    function refresh() { visit(rootItem, new Set()); }
    function reset() {
        bindings.forEach(function(binding) { if (binding) { binding.when = false; binding.destroy(); } });
        watches.forEach(function(watch) { if (watch) watch.destroy(); });
        normalizers.forEach(function(normalizer) { if (normalizer) normalizer.destroy(); });
        vectors.forEach(function(vector) { if (vector) vector.destroy(); });
        bindings = []; watches = []; images = []; normalizers = [];
        vectors = []; imageNormalizers = new WeakMap(); imageVectors = new WeakMap(); adapted = new WeakMap();
        Qt.callLater(refresh);
    }
    function snapshot() {
        return images.filter(function(item) { return item && item.sourceSize !== undefined; }).map(function(item) {
            var normalizer = imageNormalizers.get(item);
            var vector = imageVectors.get(item);
            return {width: item.width, height: item.height, smooth: item.smooth,
                sourceWidth: item.sourceSize.width, sourceHeight: item.sourceSize.height,
                normalization: normalizer ? normalizer.snapshot() : null,
                layerEnabled: item.parent.layer.enabled,
                textureWidth: item.parent.layer.textureSize.width,
                svg: vector ? {ready: vector.ready, file: vector.file || vector.generatedSource, identity: vector.identity} : null};
        });
    }
    function glyphSnapshot() {
        return vectors.filter(function(vector) { return vector && "sourceText" in vector && vector.sourceText && vector.sourceText.text !== undefined; })
            .map(function(vector) { return {text: vector.sourceText.text, file: vector.file, ready: vector.ready, visible: vector.visible}; });
    }
    onRootItemChanged: reset()
    Component.onCompleted: Qt.callLater(refresh)
}
