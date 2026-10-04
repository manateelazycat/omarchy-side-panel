import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui as ShellUi

Item {
    id: menu
    property bool opened: false
    property bool fromRight: false
    property real originY: height / 2
    property string fontFamily: PopupAppearance.fontFamily
    readonly property color foreground: PopupAppearance.foreground
    property real reveal: opened ? 1 : 0
    signal actionTriggered(string command)
    implicitWidth: actionRow.implicitWidth + PopupAppearance.horizontalPadding * 2 + 24
    implicitHeight: actionRow.implicitHeight + PopupAppearance.verticalPadding * 2 + 24
    enabled: opened
    Behavior on reveal {
        NumberAnimation { duration: menu.opened ? 250 : 160; easing.type: Easing.OutCubic }
    }
    function snapshot() {
        return {style: "shared", opened: opened, fromRight: fromRight,
            progress: Number(reveal.toFixed(3)), width: width, height: height,
            appearance: {radius: card.radius, background: String(card.color), foreground: String(foreground),
                border: String(card.border.color), borderWidth: card.border.width,
                fontSize: PopupAppearance.fontSize, fontFamily: fontFamily},
            buttons: Array.from({length: buttons.count}, function(_, index) {
                var button = buttons.itemAt(index);
                if (!button) return null;
                return {command: button.modelData.command, entrance: Number(button.entrance.toFixed(3)),
                    hovered: button.hovered, pressed: button.pressed};
            })};
    }

    Item {
        id: body
        x: 12 + (menu.fromRight ? 12 : -12) * (1 - menu.reveal)
        y: 12
        width: menu.width - 24
        height: menu.height - 24
        opacity: Math.max(0, Math.min(1, menu.reveal))
        transform: Scale {
            origin.x: menu.fromRight ? body.width : 0
            origin.y: Math.max(0, Math.min(body.height, menu.originY - body.y))
            xScale: 0.8 + 0.2 * menu.reveal
            yScale: 0.92 + 0.08 * menu.reveal
        }
        Rectangle {
            id: card
            anchors.fill: parent
            radius: PopupAppearance.radius
            antialiasing: true
            color: PopupAppearance.background
            border.width: PopupAppearance.borderWidth
            border.color: PopupAppearance.borderColor
        }
        Row {
            id: actionRow
            anchors.centerIn: parent
            spacing: Style.spacing.controlGap
            Repeater {
                id: buttons
                model: [
                    {label: "关机", command: "shutdown"},
                    {label: "注销", command: "logout"},
                    {label: "重启", command: "reboot"}
                ]
                delegate: Item {
                    id: choice
                    required property var modelData
                    required property int index
                    objectName: "power-" + modelData.command
                    width: 76
                    height: 86
                    property real entrance: 0
                    readonly property bool hovered: mouse.containsMouse
                    readonly property bool pressed: mouse.pressed
                    function animateEntrance() {
                        delay.stop();
                        enter.stop();
                        if (menu.opened) {
                            entrance = 0;
                            delay.restart();
                        }
                    }
                    Component.onCompleted: animateEntrance()
                    Connections {
                        target: menu
                        function onOpenedChanged() { choice.animateEntrance(); }
                    }
                    Timer {
                        id: delay
                        interval: (menu.fromRight ? 2 - choice.index : choice.index) * 45
                        onTriggered: enter.start()
                    }
                    NumberAnimation {
                        id: enter
                        target: choice
                        property: "entrance"
                        to: 1
                        duration: 260
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.9
                    }
                    Item {
                        anchors.fill: parent
                        opacity: Math.max(0, Math.min(1, choice.entrance))
                        transform: [
                            Translate { x: (menu.fromRight ? 10 : -10) * (1 - choice.entrance) },
                            Scale { origin.x: choice.width / 2; origin.y: 28;
                                xScale: 0.78 + 0.22 * choice.entrance; yScale: xScale }
                        ]
                        Item {
                            id: lifted
                            y: choice.pressed ? 1 : choice.hovered ? -3 : 0
                            width: choice.width
                            height: choice.height
                            scale: choice.pressed ? 0.94 : choice.hovered ? 1.06 : 1
                            Behavior on y { NumberAnimation { duration: choice.pressed ? 80 : 150; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: choice.pressed ? 80 : 150; easing.type: Easing.OutCubic } }
                            ShellUi.BorderSurface {
                                anchors.fill: parent
                                radius: PopupAppearance.radius
                                color: choice.pressed ? Style.pressedFillFor(menu.foreground, Color.accent)
                                    : choice.hovered ? Style.hoverFillFor(menu.foreground, Color.accent) : "transparent"
                                borderSpec: choice.hovered ? Border.controlSpec("hover-cursor", menu.foreground, Color.accent) : Border.none()
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            Image {
                                id: powerSymbol
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 12
                                width: 32
                                height: 32
                                source: Qt.resolvedUrl("../Icons/menu/" + choice.modelData.command + ".svg")
                                sourceSize: Qt.size(128, 128)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                visible: false
                                layer.enabled: true
                                layer.textureSize: Qt.size(128, 128)
                                layer.smooth: true
                            }
                            MultiEffect {
                                anchors.fill: powerSymbol
                                source: powerSymbol
                                colorization: 1
                                colorizationColor: menu.foreground
                                autoPaddingEnabled: false
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 58
                                height: 18
                                text: choice.modelData.label
                                color: menu.foreground
                                font.family: menu.fontFamily
                                font.pixelSize: PopupAppearance.fontSize
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        enabled: menu.opened && choice.entrance > 0.9
                        acceptedButtons: Qt.LeftButton
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: menu.actionTriggered(choice.modelData.command)
                    }
                }
            }
        }
    }
}
