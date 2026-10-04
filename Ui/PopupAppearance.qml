pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

QtObject {
    id: appearance
    readonly property int radius: 8
    readonly property int borderWidth: 1
    readonly property int horizontalPadding: 12
    readonly property int horizontalGap: 10
    readonly property int verticalPadding: 9
    readonly property int fontSize: 12
    readonly property string fontFamily: Style.font.family
    readonly property color background: Color.tooltip.background
    readonly property color foreground: Color.tooltip.text
    readonly property color borderColor: Color.tooltip.border
    property bool enabled: false
    property var stylers: []
    function registerStyler(styler) { stylers = stylers.concat([styler]); }
    function unregisterStyler(styler) { stylers = stylers.filter(function(item) { return item !== styler; }); }
    function snapshot() {
        return {enabled: enabled, radius: radius, background: String(background),
            horizontalGap: horizontalGap,
            foreground: String(foreground), border: String(borderColor), borderWidth: borderWidth,
            fontSize: fontSize, fontFamily: fontFamily,
            positioning: stylers.reduce(function(all, styler) { return all.concat(styler.positioningSnapshot()); }, []),
            popups: stylers.reduce(function(all, styler) { return all.concat(styler.snapshot()); }, [])};
    }
    property FileView configuration: FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/omarchy/shell.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { appearance.enabled = JSON.parse(text()).bar.id === "andy.side-panel"; }
            catch (error) { appearance.enabled = false; }
        }
        onLoadFailed: appearance.enabled = false
    }
}
