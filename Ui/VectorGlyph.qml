import QtQuick
import QtQuick.Effects
import "../Icons/Glyphs.js" as Glyphs

// A sibling of the native Text: keep its layout and replace only its paint.
Item {
    id: vector
    readonly property bool sidePanelVectorGlyph: true
    required property var sourceText
    property string fileOverride: ""
    readonly property string file: fileOverride || Glyphs.fileFor(sourceText.text)
    readonly property bool ready: image.status === Image.Ready
    x: sourceText.x + metrics.tightBoundingRect.x
    y: sourceText.y + sourceText.baselineOffset + metrics.tightBoundingRect.y
    width: metrics.tightBoundingRect.width
    height: metrics.tightBoundingRect.height
    visible: sourceText.visible && ready
    z: sourceText.z
    TextMetrics { id: metrics; text: vector.sourceText.text; font: vector.sourceText.font }
    Binding {
        target: vector.sourceText
        property: "opacity"
        value: 0
        when: vector.ready
        restoreMode: Binding.RestoreBindingOrValue
    }
    Image {
        id: image
        anchors.fill: parent
        visible: false
        source: vector.file ? Qt.resolvedUrl("../Icons/" + vector.file) : ""
        sourceSize: Qt.size(128, 128)
        fillMode: Image.PreserveAspectFit
        smooth: true
        // MultiEffect otherwise captures its hidden source at the small
        // native text size before the dock enlarges it.
        layer.enabled: true
        layer.textureSize: Qt.size(128, 128)
        layer.smooth: true
        layer.mipmap: false
    }
    MultiEffect {
        anchors.fill: parent
        source: image
        colorization: 1
        colorizationColor: vector.sourceText.color
        autoPaddingEnabled: false
    }
}
