import QtQuick
import QtTest
import Quickshell
import Quickshell.Services.SystemTray
import qs.Commons
import "Plugin" as Plugin

ShellRoot {
    id: root
    property int activations: 0
    property int menus: 0
    property string phase: ""
    function check(value, message) { if (!value) throw new Error(message); }
    QtObject {
        id: wechat
        property string id: "1"
        property string title: "wechat"
        property string tooltipTitle: "wechat"
        property string icon: Qt.resolvedUrl("normal.svg")
        property int status: Status.Active
        property bool onlyMenu: false
        function activate() { root.activations++; }
        function secondaryActivate() { root.activations++; }
        function scroll(delta, horizontal) {}
    }
    Plugin.TrayAttention { id: alerts; items: [wechat] }
    Item {
        id: host
        property var trayAttention: alerts
        property var options: ({pixelated: false, iconPixels: 16})
        property int barSize: 28
        property color foreground: "#dddddd"
        property string fontFamily: "monospace"
        function recordIconClick(key) {}
        function showTooltip(target, text) {}
        function hideTooltip(target) {}
    }
    Item {
        id: controller
        function trayTooltip(item) { return item.title; }
        function openTrayMenu(item, button, event) { root.menus++; }
    }
    Window {
        width: 200; height: 80; visible: true; color: "transparent"
        Plugin.TrayButton { id: a; x: 10; y: 10; host: host; controller: controller; modelData: wechat }
        Plugin.TrayButton { id: b; x: 50; y: 10; host: host; controller: controller; modelData: wechat }
        Plugin.TrayButton {
            id: lazycat; x: 100; y: 10; host: host; controller: controller
            modelData: ({id: "lzc-client-desktop_status_icon_1", title: "懒猫微服", icon: ""})
        }
        Plugin.TrayButton {
            id: flclash; x: 150; y: 10; host: host; controller: controller
            modelData: ({id: "RGagXMKVha", title: "com.follow.clash", icon: ""})
        }
    }
    TestCase { id: mouse; when: false }
    function capture(label, item) {
        var saved = false;
        (item || a).grabToImage(function(result) {
            root.check(result.saveToFile(Quickshell.env("TRAY_PREVIEW_DIR") + "/" + label + ".png"), "Capture failed");
            saved = true;
        }, Qt.size(112, 112));
        mouse.tryVerify(function() { return saved; }, 1000);
        root.check(saved, "Capture timed out");
    }
    Timer {
        interval: 200; running: true
        onTriggered: {
            try {
                root.phase = "initial native frame";
                var state = alerts.stateFor(wechat);
                Color.accent = "#7aa2f7";
                root.check(state && a.initial === "W" && b.initial === "W", "Application name was not rendered as W");
                root.check(a.outlined && a.snapshot().background === "transparent", "WeChat still uses a filled tile");
                mouse.tryVerify(function() { return state.currentFrame !== ""; }, 1000);
                root.check(state.currentFrame !== "" && !state.lastBlank, "Native frame was not sampled");
                root.check(!a.attention && !b.attention, "Normal icon raised an alert");
                root.check(lazycat.customIconFile === "tray/lazycat.svg" && flclash.customIconFile === "tray/flclash.svg",
                    "Customized tray artwork was replaced");
                capture("normal");
                capture("lazycat", lazycat);
                capture("flclash", flclash);

                // Real Catlink blink: status remains Active while the bitmap
                // alternates between a normal image and a transparent frame.
                wechat.icon = Qt.resolvedUrl("blank.svg");
                root.phase = "first blink";
                mouse.tryVerify(function() { return a.attention && b.attention; }, 1000);
                root.check(a.attention && b.attention, "Transparent blink frame did not raise shared dots");
                capture("alert");
                wechat.icon = Qt.resolvedUrl("normal.svg");
                mouse.wait(150);
                root.check(a.attention && b.attention, "Dot followed the blink's bright phase");
                mouse.mouseClick(a, 14, 14, Qt.LeftButton);
                root.check(!a.attention && !b.attention && root.activations === 1,
                    "Primary click did not clear all screen copies or activate the app");
                wechat.icon = Qt.resolvedUrl("blank.svg");
                mouse.wait(150);
                wechat.icon = Qt.resolvedUrl("normal.svg");
                mouse.wait(150);
                root.check(!a.attention && !b.attention, "Same blink episode reappeared after acknowledgement");
                mouse.tryVerify(function() { return !state.blinking; }, 3500);
                root.check(!state.blinking && !state.acknowledged, "Blink end did not reset the episode");
                capture("cleared");

                wechat.icon = Qt.resolvedUrl("blank.svg");
                root.phase = "new blink episode";
                mouse.tryVerify(function() { return a.attention; }, 1000);
                root.check(a.attention, "A new blink episode did not raise a dot");
                wechat.icon = Qt.resolvedUrl("normal.svg");
                mouse.tryVerify(function() { return !a.attention && !b.attention; }, 3500);
                root.check(!a.attention && !b.attention, "Stopped blinking left a dot behind");

                // Standard SNI attention also works, with preserved menu and
                // middle-click actions and without waiting for an image blink.
                wechat.status = Status.NeedsAttention;
                root.check(a.attention && b.attention, "SNI NeedsAttention was ignored");
                Color.accent = "#ff9944";
                capture("theme");
                mouse.mouseClick(b, 14, 14, Qt.RightButton);
                root.check(!a.attention && !b.attention && root.menus === 1, "Context menu did not dismiss the alert");
                wechat.status = Status.Active;
                wechat.status = Status.NeedsAttention;
                mouse.mouseClick(a, 14, 14, Qt.MiddleButton);
                root.check(!a.attention && root.activations === 2, "Middle click lost its action or alert dismissal");
                wechat.status = Status.Active;
                wechat.status = Status.NeedsAttention;
                wechat.status = Status.Active;
                root.check(!a.attention && !b.attention, "SNI Active did not clear the dots");
                console.log("TRAY_ATTENTION_PASS");
            } catch (error) { console.log("TRAY_ATTENTION_FAIL", root.phase, String(error), JSON.stringify(alerts.snapshot())); }
            Qt.quit();
        }
    }
    Timer { interval: 15000; running: true; onTriggered: { console.log("TRAY_ATTENTION_TIMEOUT"); Qt.quit(); } }
}
