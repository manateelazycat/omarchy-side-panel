import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons
import qs.Ui

WidgetButton {
    id: root
    required property var host
    property real magnification: 1
    property date displayDate: clock.date
    readonly property string hours: Qt.formatDateTime(displayDate, "HH")
    readonly property string minutes: Qt.formatDateTime(displayDate, "mm")
    readonly property real gray: host.foreground.r * 0.299 + host.foreground.g * 0.587 + host.foreground.b * 0.114
    readonly property color ink: Qt.rgba(gray, gray, gray, host.foreground.a)
    readonly property real pixelRatio: Screen.devicePixelRatio
    readonly property real sizeFactor: (host.options.iconSize || 28) / 28
    readonly property real baseScale: (host.options.iconSize || 28) / Style.bar.iconCanvas
    readonly property real slotHeight: (Math.max(16, Math.round(17 * sizeFactor)) * 2
        + Math.max(4, Math.round(4 * sizeFactor)) + 10)
    readonly property int digitWidth: Math.round(Math.max(10, Math.round(11 * sizeFactor)) * magnification * pixelRatio)
    readonly property int digitHeight: Math.round(Math.max(16, Math.round(17 * sizeFactor)) * magnification * pixelRatio)
    readonly property int stroke: Math.max(2, Math.round(Math.max(2, Math.round(2 * sizeFactor)) * magnification * pixelRatio))
    readonly property int gap: Math.max(3, Math.round(Math.max(4, Math.round(4 * sizeFactor)) * magnification * pixelRatio))
    readonly property int middle: Math.floor((digitHeight - stroke) / 2)
    readonly property real paintWidth: (digitWidth * 2 + gap) / pixelRatio
    readonly property real paintHeight: (digitHeight * 2 + gap) / pixelRatio

    bar: host
    hasVisualContent: true
    labelVisible: false
    fixedWidth: Math.ceil(Math.max(host.barSize * baseScale * magnification, paintWidth + 10) * pixelRatio) / pixelRatio
    fixedHeight: paintHeight + Math.round(10 * magnification * pixelRatio) / pixelRatio
    pressable: false
    tooltipText: Qt.formatDateTime(displayDate, "yyyy-MM-dd dddd HH:mm")

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // Draw at the final screen size. Every edge and stroke uses whole
    // physical pixels; hover changes geometry instead of scaling a texture.
    Item {
        id: digits
        x: Math.round((root.width - width) * root.pixelRatio / 2) / root.pixelRatio
        y: Math.round((root.height - height) * root.pixelRatio / 2) / root.pixelRatio
        width: root.paintWidth
        height: root.paintHeight
        readonly property var masks: [63, 6, 91, 79, 102, 109, 125, 7, 127, 111]
        readonly property var segments: [
            [0, 0, root.digitWidth, root.stroke],
            [root.digitWidth - root.stroke, 0, root.stroke, root.middle + root.stroke],
            [root.digitWidth - root.stroke, root.middle, root.stroke, root.digitHeight - root.middle],
            [0, root.digitHeight - root.stroke, root.digitWidth, root.stroke],
            [0, root.middle, root.stroke, root.digitHeight - root.middle],
            [0, 0, root.stroke, root.middle + root.stroke],
            [0, root.middle, root.digitWidth, root.stroke]
        ]
        Repeater {
            model: [root.hours, root.minutes]
            Item {
                id: line
                required property string modelData
                required property int index
                y: index * (root.digitHeight + root.gap) / root.pixelRatio
                width: digits.width
                height: root.digitHeight / root.pixelRatio
                Repeater {
                    model: 2
                    Item {
                        id: digit
                        required property int index
                        readonly property int mask: digits.masks[Number(line.modelData[index])]
                        x: index * (root.digitWidth + root.gap) / root.pixelRatio
                        width: root.digitWidth / root.pixelRatio
                        height: root.digitHeight / root.pixelRatio
                        Repeater {
                            model: 7
                            Rectangle {
                                required property int index
                                readonly property var segment: digits.segments[index]
                                x: segment[0] / root.pixelRatio
                                y: segment[1] / root.pixelRatio
                                width: segment[2] / root.pixelRatio
                                height: segment[3] / root.pixelRatio
                                visible: (digit.mask & (1 << index)) !== 0
                                color: root.ink
                                antialiasing: false
                            }
                        }
                    }
                }
            }
        }
    }
}
