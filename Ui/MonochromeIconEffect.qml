import QtQuick

// Sample the icon layer directly so grayscale never enables smooth filtering.
ShaderEffect {
    property var source
    fragmentShader: Qt.resolvedUrl("monochrome.frag.qsb")
    smooth: false
}
