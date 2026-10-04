import QtQuick
import Quickshell
import "Plugin/Ui" as PanelUi

ShellRoot {
    id: root
    property int rounds: 0
    property var tree: null
    property var adapters: null

    Window { id: surface; width: 120; height: 80; visible: true }
    Component {
        id: treeFactory
        Item {
            width: 80; height: 40
            Rectangle {
                width: 80; height: 40; radius: 8; border.width: 1
                Item { Text { text: "󰂛"; color: "white"; font.pixelSize: 15 } }
            }
        }
    }
    Component {
        id: adapterFactory
        Item {
            required property var sourceItem
            PanelUi.IconNormalizer { sourceItem: parent.sourceItem }
            PanelUi.IconRasterizer { rootItem: parent.sourceItem }
            PanelUi.PopupStyler { rootObject: parent.sourceItem ? parent.sourceItem.children[0] : null }
            PanelUi.IconClickTracker { rootItem: parent.sourceItem; record: function() {} }
        }
    }
    Timer {
        interval: 5; repeat: true; running: true
        onTriggered: {
            if (root.adapters) { root.adapters.destroy(); root.adapters = null; }
            if (root.tree) { root.tree.destroy(); root.tree = null; }
            gc();
            root.tree = treeFactory.createObject(surface.contentItem);
            root.adapters = adapterFactory.createObject(surface.contentItem, {sourceItem: root.tree});
            var strings = [];
            for (var i = 0; i < 500; i++) strings.push((" /usr/share/icons/application" + i + ".svg ").trim());
            gc();
            root.rounds++;
            if (root.rounds >= 500) { console.log("LIFECYCLE_PASS", root.rounds); Qt.quit(); }
        }
    }
}
