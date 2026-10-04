import QtQuick
import Quickshell
import qs.Commons

// Style the popup instances rendered by this bar. Binding restores the
// original plugin bindings when the replacement bar is disabled or unloaded.
Item {
    id: styler
    property var rootObject: null
    property string label: ""
    property var cards: []
    property var bindings: []
    property var watches: []
    property var styled: new WeakMap()

    Component { id: propertyBinding; PopupPropertyBinding {} }
    Component {
        id: visibilityWatch
        Connections {
            property var refresh: null
            ignoreUnknownSignals: true
            function onVisibleChanged() { if (target && target.visible && refresh) refresh(); }
            function onChildrenChanged() { if (refresh) Qt.callLater(refresh); }
        }
    }

    function bind(item, key, resolve) {
        var keys = styled.get(item) || [];
        if (keys.indexOf(key) !== -1) return;
        var binding = propertyBinding.createObject(styler, {target: item, property: key, resolve: resolve});
        bindings.push(binding);
        styled.set(item, keys.concat([key]));
    }
    function children(item) {
        var result = [];
        ["data", "children"].forEach(function(key) {
            if (!(key in item) || !item[key]) return;
            var list = item[key];
            for (var i = 0; i < list.length; i++) {
                if (list[i] && result.indexOf(list[i]) === -1) result.push(list[i]);
            }
        });
        return result;
    }
    function walk(item, visit, seen) {
        if (!item || item === styler || seen.has(item)) return;
        seen.add(item);
        if (visit(item) === false) return;
        children(item).forEach(function(child) { walk(child, visit, seen); });
    }
    function isWindow(item) { return "contentItem" in item && "screen" in item && "backingWindowVisible" in item; }
    function addCard(card, window) {
        if (cards.some(function(record) { return record.card === card; })) return;
        cards = cards.concat([{card: card, window: window}]);
        bind(card, "radius", function() { return PopupAppearance.radius; });
        bind(card, "color", function() { return PopupAppearance.background; });
        if ("borderSpec" in card) {
            bind(card, "borderSpec", function() { return Border.flat(PopupAppearance.borderColor, PopupAppearance.borderWidth); });
            bind(card, "topPadding", function() { return PopupAppearance.verticalPadding - PopupAppearance.borderWidth; });
            bind(card, "bottomPadding", function() { return PopupAppearance.verticalPadding - PopupAppearance.borderWidth; });
            bind(card, "leftPadding", function() { return PopupAppearance.horizontalPadding - PopupAppearance.borderWidth; });
            bind(card, "rightPadding", function() { return PopupAppearance.horizontalPadding - PopupAppearance.borderWidth; });
        } else {
            bind(card, "border.color", function() { return PopupAppearance.borderColor; });
            bind(card, "border.width", function() { return PopupAppearance.borderWidth; });
        }
        if (window && "padding" in window)
            bind(window, "padding", function() { return PopupAppearance.verticalPadding - PopupAppearance.borderWidth; });
        watches.push(visibilityWatch.createObject(styler, {target: window || card, refresh: function() { styler.refresh(); }}));
    }
    function discover() {
        if (!rootObject) return;
        if ("radius" in rootObject && "border" in rootObject) {
            addCard(rootObject, rootObject.QsWindow.window);
        } else {
            walk(rootObject, function(item) {
                if (!isWindow(item)) return true;
                children(item).forEach(function(child) {
                    walk(child, function(candidate) {
                        if ("borderSpec" in candidate && "contentTopInset" in candidate && "radius" in candidate) {
                            addCard(candidate, item);
                            return false;
                        }
                        return true;
                    }, new Set());
                });
                return false;
            }, new Set());
        }
        refresh();
    }
    function isGlyph(text) {
        return /^[\s\uE000-\uF8FF\u{F0000}-\u{FFFFD}\u{100000}-\u{10FFFD}]+$/u.test(String(text || ""));
    }
    function styleContent(card) {
        walk(card, function(item) {
            if (item.visible === false) return false;
            // Tray entries and submenu delegates can arrive after mapping.
            // React before the next frame instead of waiting for the timer.
            if (!("font" in item) && !("radius" in item) && "children" in item) {
                var keys = styled.get(item) || [];
                if (keys.indexOf("childrenWatch") === -1) {
                    styled.set(item, keys.concat(["childrenWatch"]));
                    watches.push(visibilityWatch.createObject(styler, {target: item, refresh: function() { styler.refresh(); }}));
                }
            }
            if ("font" in item && "text" in item && !isGlyph(item.text)) {
                bind(item, "font.family", function() { return PopupAppearance.fontFamily; });
                bind(item, "font.pixelSize", function() { return PopupAppearance.fontSize; });
                if ("color" in item && !Border.sameColor(item.color, Color.urgent))
                    bind(item, "color", function() { return PopupAppearance.foreground; });
            }
            if (item !== card && "radius" in item && "color" in item) {
                // Keep circular status marks, radio buttons, and switch thumbs.
                if (item.width > item.height * 1.4 || item.radius <= PopupAppearance.radius)
                    bind(item, "radius", function() { return PopupAppearance.radius; });
                // Nested dialogs share the outer chrome. Leave control fills
                // bound to their hover, selection, checked and disabled states.
                if ("anchors" in item && item.anchors.centerIn
                    && item.width >= 120 && item.height >= 80
                    && "border" in item && item.border.width > 0 && !("borderSpec" in item)) {
                    bind(item, "color", function() { return PopupAppearance.background; });
                    bind(item, "border.color", function() { return PopupAppearance.borderColor; });
                    bind(item, "border.width", function() { return PopupAppearance.borderWidth; });
                }
            }
            return true;
        }, new Set());
    }
    function refresh() {
        if (!PopupAppearance.enabled) return;
        cards.forEach(function(record) {
            if (record.card && !record.window) record.window = record.card.QsWindow.window;
            if (record.card && (!record.window || record.window.visible)) styleContent(record.card);
        });
    }
    function reset() {
        bindings.forEach(function(binding) { if (binding) binding.destroy(); });
        watches.forEach(function(watch) { if (watch) watch.destroy(); });
        bindings = []; watches = []; cards = []; styled = new WeakMap();
        Qt.callLater(discover);
    }
    function snapshot() {
        return cards.filter(function(record) {
            if (record.card && !record.window) record.window = record.card.QsWindow.window;
            return record.card && record.window && record.window.visible;
        })
            .map(function(record) {
                var card = record.card;
                var fonts = [];
                walk(card, function(item) {
                    if (item.visible === false) return false;
                    if ("font" in item && "text" in item && !isGlyph(item.text)
                        && fonts.indexOf(item.font.pixelSize) === -1) fonts.push(item.font.pixelSize);
                    return true;
                }, new Set());
                return {id: styler.label, screen: record.window.screen ? record.window.screen.name : "",
                    radius: card.radius, background: String(card.color),
                    border: String(card.border.color), borderWidth: card.border.width,
                    width: card.width, height: card.height, textSizes: fonts};
            });
    }
    onRootObjectChanged: reset()
    Component.onCompleted: { PopupAppearance.registerStyler(styler); Qt.callLater(discover); }
    Component.onDestruction: PopupAppearance.unregisterStyler(styler)
    Timer { interval: 200; repeat: true; running: PopupAppearance.enabled && styler.cards.length > 0; onTriggered: styler.refresh() }
    Connections { target: PopupAppearance; function onEnabledChanged() { if (PopupAppearance.enabled) styler.refresh(); } }
}
