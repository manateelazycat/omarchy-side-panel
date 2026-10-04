import QtQuick
import Quickshell
import Quickshell.Io
import "TraySvg.js" as Svg

Item {
    id: vector
    readonly property bool sidePanelVectorGlyph: true
    required property var sourceImage
    required property var trayIcon
    readonly property var trayItem: trayIcon.parent && "modelData" in trayIcon.parent ? trayIcon.parent.modelData : null
    readonly property string identity: trayItem ? String(trayItem.id || trayItem.title || trayItem.tooltipTitle || "") : ""
    readonly property string originalSource: String(trayIcon.icon || "")
    readonly property string file: Svg.packagedFile(identity, originalSource)
    readonly property bool ready: image.status === Image.Ready
    property string generatedSource: ""
    property string loadedSource: ""
    anchors.fill: parent
    Binding { target: vector.sourceImage; property: "opacity"; value: 0; when: vector.ready; restoreMode: Binding.RestoreBindingOrValue }
    Image {
        id: image
        anchors.fill: parent
        source: vector.file ? Qt.resolvedUrl("../Icons/"+vector.file) : vector.generatedSource
        sourceSize: Qt.size(128,128)
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: vector.ready
    }
    function refresh() {
        generatedSource = "";
        if (loadedSource) probe.unloadImage(loadedSource);
        loadedSource = originalSource;
        if (!file && loadedSource) probe.loadImage(loadedSource,Qt.size(128,128));
    }
    onOriginalSourceChanged: Qt.callLater(refresh)
    onFileChanged: Qt.callLater(refresh)
    Component.onCompleted: Qt.callLater(refresh)
    FileView {
        id: cache
        preload: false
        printErrors: false
        onSaved: vector.generatedSource = "file://"+path
    }
    Canvas {
        id: probe
        width: 128; height: 128
        opacity: 0
        onAvailableChanged: if (available) vector.refresh()
        onImageLoaded: requestPaint()
        onPaint: {
            if (vector.file || !vector.loadedSource || !isImageLoaded(vector.loadedSource)) return;
            var ctx=getContext("2d");ctx.reset();ctx.drawImage(vector.loadedSource,0,0,width,height);
            var svg=Svg.trace(ctx.getImageData(0,0,width,height).data,width,height);
            var base=Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME")+"/.cache";
            cache.path=base+"/omarchy-side-panel/icons/tray-"+Svg.hash(svg)+".svg";
            cache.setText(svg);
        }
    }
}
