import QtQuick

// Sample the icon layer directly; callers select pixel or smooth filtering.
ShaderEffect {
    property var source
    fragmentShader: Qt.resolvedUrl("monochrome.frag.qsb")
    smooth: false
}
