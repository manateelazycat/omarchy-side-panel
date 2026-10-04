import QtQuick
import QtQuick.Effects

Item {
    id: root
    property string initial: "?"
    property color foreground: "white"
    property color attentionColor: foreground
    property color background: "#666666"
    property string fontFamily: "monospace"
    property bool attention: false
    property bool outlined: false
    property url customIconSource: ""
    readonly property bool customized: String(customIconSource) !== ""
    readonly property bool vectorArtwork: customized || outlined
    readonly property real gray: foreground.r * 0.299 + foreground.g * 0.587 + foreground.b * 0.114
    readonly property color glyphColor: Qt.rgba(gray, gray, gray, foreground.a)

    Rectangle {
        anchors.fill: parent
        radius: width * 0.2
        color: root.background
        visible: !root.vectorArtwork
        antialiasing: true
    }
    Text {
        anchors.fill: parent
        text: root.initial
        color: "white"
        font.family: root.fontFamily
        font.pixelSize: Math.round(parent.height * 0.72)
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
        visible: !root.vectorArtwork
        // Recolor the letter alone. A shader on the opaque tile can flatten
        // both background and glyph into a solid block on the desktop.
        layer.enabled: true
        layer.textureSize: Qt.size(Math.ceil(width * 8), Math.ceil(height * 8))
        layer.smooth: true
        layer.effect: MonochromeIconEffect { ink: root.foreground; smooth: true }
    }
    Image {
        id: artwork
        anchors.fill: parent
        source: root.customized ? root.customIconSource : root.outlined ? Qt.resolvedUrl("../Icons/tray/wechat.svg") : ""
        sourceSize: Qt.size(128, 128)
        fillMode: Image.PreserveAspectFit
        visible: false
        layer.enabled: true
        layer.textureSize: Qt.size(128, 128)
        layer.smooth: true
    }
    MultiEffect {
        anchors.fill: parent
        source: artwork
        visible: root.vectorArtwork
        colorization: 1
        colorizationColor: root.glyphColor
        autoPaddingEnabled: false
    }
    Rectangle {
        width: root.width * 0.25
        height: width
        x: root.width - width
        y: 0
        radius: width / 2
        color: root.attentionColor
        visible: root.attention
        antialiasing: true
    }
}
