import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "Ui" as PanelUi

ShellRoot {
    id: root
    property var commands: []
    function check(value, message) { if (!value) throw new Error(message); }
    Window {
        width: menu.implicitWidth + 40; height: menu.implicitHeight + 40; visible: true; color: "#101010"
        Rectangle {
            id: preview
            anchors.fill: parent
            color: "#101010"
            PanelUi.PowerCapsule {
                id: menu
                x: 20; y: 20; width: implicitWidth; height: implicitHeight
                onActionTriggered: function(command) {
                    root.commands = root.commands.concat([command]);
                    opened = false;
                }
            }
        }
    }
    TestCase { id: input; when: false }
    function button(command) { return input.findChild(menu, "power-" + command); }
    function capture(name) {
        var saved = false;
        var success = false;
        check(preview.grabToImage(function(result) {
            success = result.saveToFile(Quickshell.env("POWER_PREVIEW_DIR") + "/" + name + ".png");
            saved = true;
        }, Qt.size(preview.width * 3, preview.height * 3)), "Capture could not start");
        for (var i = 0; i < 100 && !saved; i++) input.wait(10);
        check(saved && success, "Capture failed: " + name);
    }
    function open(fromRight) {
        input.mouseMove(preview, 5, 5);
        menu.fromRight = fromRight;
        menu.opened = true;
        input.wait(40);
        var states = menu.snapshot().buttons;
        check(fromRight ? states[2].entrance > states[0].entrance : states[0].entrance > states[2].entrance,
              "Entry did not start next to the dock");
        input.wait(400);
        check(menu.reveal === 1 && menu.snapshot().buttons.every(function(item) { return item.entrance === 1; }),
              "Entry did not settle");
    }
    Timer {
        interval: 200; running: true
        onTriggered: {
            try {
                input.mouseClick(button("shutdown"), 38, 28);
                check(commands.length === 0, "Closed menu triggered an action");
                open(false);
                capture("normal");
                input.mouseMove(button("shutdown"), 38, 28);
                input.wait(180);
                check(button("shutdown").hovered, "Hover did not reach the circular button");
                capture("hover");
                input.mousePress(button("shutdown"), 38, 28);
                input.wait(110);
                check(button("shutdown").pressed, "Press did not reach the button");
                capture("pressed");
                input.mouseRelease(button("shutdown"), 38, 28);
                check(commands.join() === "shutdown" && !menu.opened, "Shutdown signal/close failed");
                input.mouseClick(button("shutdown"), 38, 28);
                check(commands.length === 1, "Closing menu accepted a second action");
                input.wait(200);
                check(menu.reveal === 0, "Menu did not finish closing");

                for (var side = 0; side < 2; side++) {
                    for (var j = 0; j < 3; j++) {
                        var command = ["shutdown", "logout", "reboot"][j];
                        open(side === 1);
                        if (side === 1 && j === 0) capture("right");
                        input.mouseClick(button(command), 38, 28);
                        check(commands[commands.length - 1] === command && !menu.opened,
                              "Wrong action or closing state: " + command);
                        input.wait(200);
                    }
                }
                // Cancel delayed entrances, then reopen before the fade ends.
                menu.opened = true; input.wait(25);
                menu.opened = false; input.wait(25);
                menu.opened = true; input.wait(450);
                check(menu.snapshot().buttons.every(function(item) { return item.entrance === 1; }),
                      "Rapid reopening left a stale entry timer");
                menu.opened = false; input.wait(200);
                check(commands.length === 7 && menu.reveal === 0, "Extra power action or unfinished fade");
                console.log("CAPSULE_PASS", JSON.stringify(commands));
            } catch (error) { console.log("CAPSULE_FAIL", String(error), JSON.stringify(menu.snapshot())); }
            Qt.quit();
        }
    }
}
