import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

// One recovery controller per bar, shared by all screens. Some SNI bridges
// keep exporting their item but do not register again after Shell restarts.
Item {
    id: root
    readonly property string helperPath: decodeURIComponent(String(Qt.resolvedUrl("recover-tray.py")).replace(/^file:\/\//, ""))
    readonly property int trayItemCount: SystemTray.items.values.length
    property var result: ({watcher: false, recovered: [], pending: 0, error: ""})
    property int recoveredCount: 0
    property int scans: 0
    property var lastRecovered: []
    property int retryDelay: 1000
    property bool rescan: false

    function requestScan() {
        retryDelay = 1000;
        if (scan.running) { rescan = true; return; }
        scanTimer.interval = 250;
        scanTimer.restart();
    }
    function snapshot() {
        return {monitoring: monitor.running, scanning: scan.running, watcher: result.watcher,
            items: trayItemCount, scans: scans, pending: result.pending, recoveredCount: recoveredCount,
            lastRecovered: lastRecovered, error: result.error};
    }

    Process {
        id: scan
        command: ["python3", root.helperPath]
        stdout: StdioCollector { id: output }
        onExited: function(code) {
            root.scans += 1;
            try { root.result = JSON.parse(output.text); }
            catch (error) { root.result = {watcher: false, recovered: [], pending: 0, error: String(error)}; }
            if (root.result.recovered.length) {
                root.lastRecovered = root.result.recovered;
                root.recoveredCount += root.result.recovered.length;
            }
            var retry = code !== 0 || !root.result.watcher || root.result.pending > 0;
            scanTimer.interval = root.rescan ? 250 : retry ? root.retryDelay : 30000;
            root.retryDelay = retry ? Math.min(root.retryDelay * 2, 30000) : 1000;
            root.rescan = false;
            scanTimer.restart();
        }
    }
    Timer {
        id: scanTimer
        interval: 250
        running: true
        repeat: true
        // Also reconcile periodically if signal monitoring is unavailable.
        onTriggered: if (!scan.running) scan.running = true
    }
    Process {
        id: monitor
        command: ["busctl", "--user", "--json=short",
            "--match=type='signal',sender='org.freedesktop.DBus',interface='org.freedesktop.DBus',member='NameOwnerChanged'", "monitor"]
        running: true
        onStarted: root.requestScan()
        onRunningChanged: if (!running) monitorRestart.restart()
        stdout: SplitParser {
            onRead: function(data) {
                try {
                    var message = JSON.parse(data);
                    var name = message.payload && message.payload.data ? message.payload.data[0] : "";
                    if (name === "org.kde.StatusNotifierWatcher"
                        || /^org\.(kde|freedesktop)\.StatusNotifierItem-\d+-\d+$/.test(name))
                        root.requestScan();
                } catch (error) {}
            }
        }
    }
    Timer {
        id: monitorRestart
        interval: 5000
        onTriggered: if (!monitor.running) monitor.running = true
    }
}
