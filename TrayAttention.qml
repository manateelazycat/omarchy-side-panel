import QtQuick
import Quickshell.Services.SystemTray
import "TrayIconModel.js" as TrayModel

// Share each alert and its acknowledgement across every screen's tray cell.
Item {
    id: root
    property var items: SystemTray.items.values
    property var states: []

    function stateFor(item) { return states.find(function(state) { return state.modelData === item; }) || null; }
    function snapshot() { return states.map(function(state) { return state.snapshot(); }); }

    Instantiator {
        model: root.items
        onObjectAdded: function(index, object) { root.states = root.states.concat([object]); }
        onObjectRemoved: function(index, object) { root.states = root.states.filter(function(state) { return state !== object; }); }
        delegate: Item {
            id: state
            required property var modelData
            readonly property bool protocolAttention: modelData.status === Status.NeedsAttention
            property bool blinking: false
            property bool acknowledged: false
            readonly property bool requested: protocolAttention || blinking
            readonly property bool pending: requested && !acknowledged
            property string currentFrame: ""
            property string previousFrame: ""
            property bool lastBlank: true
            property double lastFrameTime: 0

            function acknowledge() { if (requested) acknowledged = true; }
            function observeFrame(frame) {
                if (frame.signature === currentFrame) return;
                var now = Date.now();
                var becameBlank = currentFrame !== "" && frame.blank && !lastBlank;
                var alternating = frame.signature === previousFrame && now - lastFrameTime <= 2000;
                if (becameBlank || alternating) blinking = true;
                previousFrame = currentFrame;
                currentFrame = frame.signature;
                lastBlank = frame.blank;
                lastFrameTime = now;
                if (blinking) stopped.restart();
            }
            function snapshot() {
                return {name: TrayModel.name(modelData), initial: TrayModel.initial(modelData),
                    attention: pending, protocolAttention: protocolAttention,
                    blinking: blinking, acknowledged: acknowledged};
            }
            onRequestedChanged: if (!requested) acknowledged = false
            Timer {
                id: stopped
                interval: 2500
                onTriggered: state.blinking = false
            }
        }
    }
}
