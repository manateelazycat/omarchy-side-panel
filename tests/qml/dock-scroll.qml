import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "Ui" as PanelUi

ShellRoot {
    id: root
    property int nativeWheels: 0
    property int clicks: 0
    property real minimumSeen: 0
    property real maximumSeen: 0
    function check(value, message) { if (!value) throw new Error(message); }
    Window {
        width: 200; height: 160; visible: true
        PanelUi.ElasticFlickable {
            id: scroll
            x: 20; y: 20; width: 120; height: 100
            contentHeight: 400
            onContentYChanged: {
                root.minimumSeen = Math.min(root.minimumSeen, contentY);
                root.maximumSeen = Math.max(root.maximumSeen, contentY);
            }
            Repeater {
                model: 8
                Rectangle {
                    required property int index
                    width: 120; height: 50; y: index * 50
                    color: index % 2 ? "#222222" : "#444444"
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.clicks++
                        onWheel: root.nativeWheels++
                    }
                }
            }
        }
    }
    TestCase { id: input; when: false }
    function wheel(delta, modifiers) {
        input.mouseWheel(scroll, 60, 50, 0, delta, Qt.NoButton, modifiers || Qt.NoModifier, 0);
    }
    function position(value) {
        scroll.wheelDriving = false;
        scroll.contentY = value;
    }
    function settle(expected) {
        for (var i = 0; i < 150 && (scroll.wheelAnimating || Math.abs(scroll.contentY - expected) >= 0.2); i++)
            input.wait(20);
        check(!scroll.wheelAnimating && Math.abs(scroll.contentY - expected) < 0.2,
            "Scroll did not settle at " + expected + ": " + scroll.contentY);
    }
    Timer {
        interval: 200; running: true
        onTriggered: {
            try {
                wheel(-120);
                input.wait(40);
                check(scroll.contentY > 0 && scroll.contentY < scroll.wheelStep, "Wheel jumped instead of animating");
                check(nativeWheels === 0, "Icon consumed navigation wheel");
                settle(54);
                input.mouseClick(scroll, 60, 50);
                check(clicks === 1, "Wheel overlay blocked icon clicks");
                wheel(-120, Qt.AltModifier);
                check(nativeWheels === 1, "Alt wheel did not reach icon");
                check(!scroll.wheelAnimating, "Alt wheel also moved the list");

                wheel(-120); input.wait(30);
                wheel(-120); input.wait(30);
                wheel(120);
                settle(108);

                position(scroll.maximumY);
                maximumSeen = scroll.contentY;
                wheel(-120);
                settle(scroll.maximumY);
                check(maximumSeen > scroll.maximumY + 1, "Bottom did not stretch and rebound");
                check(maximumSeen < scroll.maximumY + 50, "Bottom overshoot was unbounded");

                position(0);
                minimumSeen = 0;
                wheel(120);
                settle(0);
                check(minimumSeen < -1 && minimumSeen > -50, "Top did not stretch and rebound");

                // The same small overflow as the real taskbar: repeated
                // ticks must still reach the last icon and return to bounds.
                scroll.contentHeight = scroll.height + 22;
                for (var i = 0; i < 8; i++) { wheel(-120); input.wait(20); }
                settle(22);
                wheel(120);
                input.wait(40);
                scroll.contentHeight = 80;
                input.wait(50);
                check(scroll.contentY === 0 && !scroll.wheelAnimating, "Shrinking content left a stale animation");
                var previous = nativeWheels;
                wheel(-120);
                check(nativeWheels === previous + 1 && scroll.contentY === 0, "Fitting content stole native wheel");
                scroll.contentHeight = 400;
                scroll.wheelScrollingEnabled = false;
                input.wait(100);
                wheel(-120);
                check(nativeWheels === previous + 2, "Disabled navigation stole native wheel");
                console.log("SCROLL_PASS", "range", scroll.maximumY, "top", minimumSeen, "bottom", maximumSeen);
            } catch (error) { console.log("SCROLL_FAIL", String(error), "y", scroll.contentY, "target", scroll.wheelTarget, "running", scroll.wheelAnimating); }
            Qt.quit();
        }
    }
}
