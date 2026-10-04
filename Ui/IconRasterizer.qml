import QtQuick
import qs.Commons

// Keep bitmap samples intact before the widget's nearest-filtered layer is
// enlarged. Only walk visual children: separate menu windows keep their UI.
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
    property var adapted: new WeakMap()

    Component {
        id: propertyBinding
        Binding {
            required property var adapter
            required property var resolve
            property bool unconditional: false
            value: resolve()
            when: unconditional || adapter.pixelated
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
    function bind(item, key, resolve, unconditional) {
        bindings.push(propertyBinding.createObject(rasterizer,
            {adapter: rasterizer, target: item, property: key, resolve: resolve, unconditional: !!unconditional}));
    }
    function visit(item, seen) {
        if (!item || item === rasterizer || "sidePanelIconNormalizer" in item || seen.has(item)) return;
        seen.add(item);
        if (!adapted.has(item)) {
            adapted.set(item, true);
            if ("sourceSize" in item && "fillMode" in item) {
                images.push(item);
                bind(item, "smooth", function() { return false; });
                bind(item, "mipmap", function() { return false; });
                bind(item, "sourceSize.width", function() { return rasterizer.pixels; });
                bind(item, "sourceSize.height", function() { return rasterizer.pixels; });
                var icon = item.parent;
                if (icon && "symbolic" in icon && "icon" in icon) {
                    bind(icon, "width", function() { return Style.bar.iconCanvas; }, true);
                    bind(icon, "height", function() { return Style.bar.iconCanvas; }, true);
                    var normalizer = iconNormalizer.createObject(rasterizer, {parent: rasterizer,
                        sourceItem: icon, targetSize: Style.bar.iconCanvas});
                    normalizers.push(normalizer);
                    imageNormalizers.set(item, normalizer);
                    bind(icon, "layer.enabled", function() { return true; }, true);
                    bind(icon, "layer.sourceRect", function() { return normalizer.sourceRect; }, true);
                    bind(icon, "layer.textureSize", function() {
                        return rasterizer.pixelated ? Qt.size(rasterizer.pixels, rasterizer.pixels) : Qt.size(0, 0);
                    }, true);
                    bind(icon, "layer.smooth", function() { return !rasterizer.pixelated; }, true);
                    bind(icon, "layer.mipmap", function() { return false; }, true);
                }
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
        bindings.forEach(function(binding) { if (binding) binding.destroy(); });
        watches.forEach(function(watch) { if (watch) watch.destroy(); });
        normalizers.forEach(function(normalizer) { if (normalizer) normalizer.destroy(); });
        bindings = []; watches = []; images = []; normalizers = [];
        imageNormalizers = new WeakMap(); adapted = new WeakMap();
        Qt.callLater(refresh);
    }
    function snapshot() {
        return images.filter(function(item) { return item && item.sourceSize !== undefined; }).map(function(item) {
            var normalizer = imageNormalizers.get(item);
            return {width: item.width, height: item.height, smooth: item.smooth,
                sourceWidth: item.sourceSize.width, sourceHeight: item.sourceSize.height,
                normalization: normalizer ? normalizer.snapshot() : null};
        });
    }
    onRootItemChanged: reset()
    Component.onCompleted: Qt.callLater(refresh)
}
