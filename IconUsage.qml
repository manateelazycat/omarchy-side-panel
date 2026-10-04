import QtQuick
import Quickshell
import Quickshell.Io
import "UsageModel.js" as Usage

Item {
    id: usage
    property string path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state")
        + "/omarchy-side-panel/click-counts.json"
    property var counts: ({})
    property bool ready: false
    property string error: ""
    property bool readable: true

    function load() {
        if (ready) return;
        try { counts = Usage.decode(file.text()); }
        catch (exception) {
            readable = false;
            error = String(exception);
            console.warn("Side panel click counts:", error, path);
        }
        ready = true;
    }
    function record(key) {
        if (!key) return;
        load();
        counts = Usage.increment(counts, key);
        // Complete the atomic write before a reload action can stop the shell.
        // Keep an unreadable/unknown-version file intact for recovery.
        if (readable) file.setText(JSON.stringify({version: 1, counts: counts}, null, 2) + "\n");
    }
    function snapshot() { return {path: path, counts: counts, ready: ready, error: error}; }
    Component.onCompleted: load()

    FileView {
        id: file
        path: usage.path
        preload: false
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        printErrors: false
        onLoadFailed: function(code) {
            if (code !== FileViewError.FileNotFound) {
                usage.readable = false;
                usage.error = "Could not read click counts (" + code + ")";
                console.warn("Side panel:", usage.error, usage.path);
            }
        }
        onSaved: usage.error = ""
        onSaveFailed: function(code) {
            usage.error = "Could not save click counts (" + code + ")";
            console.warn("Side panel:", usage.error, usage.path);
        }
    }
}
