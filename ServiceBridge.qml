import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// These widgets use a private service rather than a PopupCard. A replacement
// bar receives no live service object; use each plugin's existing public IPC.
Item {
    id: root
    required property string pluginId
    required property var delegateShell
    property bool opened: false
    property bool automationEnabled: true
    readonly property bool onBattery: UPower.onBattery
    readonly property string tooltipText: "Power Awake · " + (automationEnabled ? "Enabled" : "Disabled")
    readonly property var bar: delegateShell ? delegateShell.bar : null

    function serviceFor(id) { return id === pluginId ? root : null; }
    function firstPartyServiceFor(id) { return delegateShell ? delegateShell.firstPartyServiceFor(id) : null; }
    function toggle() {
        if (action.running) return;
        action.command = ["omarchy-shell", root.pluginId, "toggle"];
        action.running = true;
    }
    function summon(id, payload) { return delegateShell ? delegateShell.summon(id, payload || "{}") : false; }
    function hide(id) { return delegateShell ? delegateShell.hide(id) : false; }
    function isPluginOpen(id) { return delegateShell ? delegateShell.isPluginOpen(id) : false; }
    function updateEntryInline(id, settings) { return delegateShell ? delegateShell.updateEntryInline(id, settings) : false; }

    Process {
        id: action
        onExited: if (root.pluginId === "io.github.manateelazycat.power-awake") status.running = true
    }
    Process {
        id: status
        command: ["omarchy-shell", root.pluginId, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.automationEnabled = JSON.parse(text).enabled === true; } catch (error) {}
            }
        }
    }
    Timer {
        interval: 5000
        running: root.pluginId === "io.github.manateelazycat.power-awake"
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!status.running) status.running = true
    }
}
