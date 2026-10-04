import QtQuick

Flickable {
    id: scroll
    property bool wheelScrollingEnabled: true
    property real wheelStep: 54
    property real overshootLimit: Math.min(32, height / 5)
    readonly property bool overflowing: contentHeight > height
    readonly property real maximumY: Math.max(0, contentHeight - height)
    readonly property bool wheelAnimating: wheelMotion.running
    property real wheelTarget: 0
    property bool wheelDriving: false
    clip: true
    contentWidth: width
    flickableDirection: Flickable.VerticalFlick
    interactive: wheelScrollingEnabled && overflowing
    boundsBehavior: Flickable.DragAndOvershootBounds
    maximumFlickVelocity: 1600
    flickDeceleration: 3000
    rebound: Transition {
        NumberAnimation { properties: "x,y"; duration: 500; easing.type: Easing.OutElastic; easing.amplitude: 0.6; easing.period: 0.4 }
    }

    function bounded(value) { return Math.max(0, Math.min(maximumY, value)); }
    function scrollBy(amount) {
        if (!wheelScrollingEnabled || !overflowing || !isFinite(amount) || amount === 0) return;
        if (!wheelMotion.running && !wheelIdle.running) wheelTarget = contentY;
        cancelFlick();
        wheelTarget = Math.max(-overshootLimit, Math.min(maximumY + overshootLimit, wheelTarget + amount));
        // Behavior retargets the spring while preserving its current motion.
        wheelDriving = true;
        contentY = wheelTarget;
        wheelIdle.restart();
    }
    function finishWheel() {
        if (!wheelMotion.running && !wheelIdle.running) wheelTarget = contentY;
        wheelIdle.stop();
        cancelFlick();
        wheelTarget = bounded(wheelTarget);
        wheelDriving = true;
        contentY = wheelTarget;
    }
    function constrainContent() {
        if (!overflowing) {
            wheelIdle.stop();
            cancelFlick();
            wheelDriving = false;
            wheelMotion.stop();
            wheelTarget = 0;
            contentY = 0;
        } else if (wheelTarget < 0 || wheelTarget > maximumY || contentY < 0 || contentY > maximumY) {
            wheelTarget = contentY;
            finishWheel();
        }
    }
    onMaximumYChanged: constrainContent()
    onWheelScrollingEnabledChanged: if (!wheelScrollingEnabled) finishWheel()
    onDraggingChanged: if (dragging) {
        wheelIdle.stop();
        wheelDriving = false;
        wheelMotion.stop();
    }
    Behavior on contentY {
        enabled: scroll.wheelDriving
        SpringAnimation {
            id: wheelMotion
            spring: 4
            damping: 0.35
            epsilon: 0.1
        }
    }
    Timer { id: wheelIdle; interval: 180; onTriggered: scroll.finishWheel() }

    // Keep wheel delivery above icon MouseAreas without intercepting their
    // clicks or hover. Modified wheels fall through to native icon actions.
    Item {
        parent: scroll
        anchors.fill: parent
        z: 1
        WheelHandler {
            target: null
            enabled: scroll.wheelScrollingEnabled && scroll.overflowing
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            acceptedModifiers: Qt.NoModifier
            blocking: true
            onWheel: function(event) {
                var amount = event.pixelDelta.y !== 0 ? -event.pixelDelta.y
                    : -event.angleDelta.y / 120 * scroll.wheelStep;
                if (amount === 0) { event.accepted = false; return; }
                event.accepted = true;
                scroll.scrollBy(amount);
            }
        }
    }
}
