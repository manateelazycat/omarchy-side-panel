import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Plugin" as Plugin
import "Plugin/Ui" as PanelUi

ShellRoot {
    id: root
    property var entries: []
    property var adapters: []
    property int pending: 0
    property bool failed: false
    property int phase: 0
    Item {
        id: testHost
        property bool vertical: true
        property int barSize: 28
        property color foreground: "#dddddd"
        property color barForeground: foreground
        property color urgent: foreground
        property string fontFamily: "monospace"
        property bool foregroundAnimationEnabled: false
        property var options: ({pixelated: false, iconPixels: 16})
        property bool recording: false
        property bool stayAwake: false
        property bool doNotDisturb: false
        function hideTooltip(target) {}
        function showTooltip(target,text) {}
    }
    Item {
        id: testController
        function trayIconSource(icon) { return icon; }
        function iconIsSymbolic(icon) { return false; }
    }
    FileView { id: records; path: Qt.resolvedUrl("records.json"); blockLoading: true }
    Window {
        id: window
        width: 720; height: 180; visible: true; color: "#181818"
        Item { id: canvas; anchors.fill: parent }
    }
    Component { id: wrapperFactory; Item { width: 28; height: Style.bar.iconSlot } }
    Component { id: buttonFactory; BarIconButton { bar: testHost; fixedWidth: 28; fixedHeight: Style.bar.iconSlot } }
    Component { id: normalizerFactory; PanelUi.IconNormalizer {} }
    Component { id: effectFactory; PanelUi.MonochromeIconEffect { ink: testHost.foreground; smooth: true } }
    Component { id: actionFactory; Plugin.ActionIcon { host: testHost } }
    Component { id: clockFactory; Plugin.ClockIcon { host: testHost } }
    Component { id: trayFactory; Plugin.TrayButton { host: testHost; controller: testController } }
    Component { id: rasterizerFactory; PanelUi.IconRasterizer { pixelated: false } }
    function add(name, item, normalizer) {
        var wrapper = wrapperFactory.createObject(canvas,{x:entries.length*32+4,y:40});
        if ("slotHeight" in item) {
            wrapper.width = item.implicitWidth;
            wrapper.height = item.implicitHeight;
        }
        item.parent=wrapper; item.x=0; item.y=0;
        root.entries = entries.concat([{name:name,item:wrapper,source:item,normalizer:normalizer}]);
    }
    function switchInputMode(item) {
        if ("chinese" in item) item.chinese = true;
        if ("children" in item)
            for (var i=0;i<item.children.length;i++) switchInputMode(item.children[i]);
    }
    Component.onCompleted: {
        var list=JSON.parse(records.text());
        for(var i=0;i<list.length;i++) {
            var component=Qt.createComponent("file://"+list[i].url);
            if(component.status!==Component.Ready) throw new Error(component.errorString());
            var button=buttonFactory.createObject(canvas,{iconComponent:component});
            var normalizer=normalizerFactory.createObject(canvas,{sourceItem:button,targetSize:16});
            button.layer.enabled=true;
            button.layer.textureSize=Qt.size(128,128);
            button.layer.sourceRect=Qt.binding(function(n){return function(){return n.sourceRect;};}(normalizer));
            button.layer.effect=effectFactory;
            add(list[i].name,button,normalizer);
        }
        var actions=["power","recording","idle","notifications","reload"];
        for(var j=0;j<actions.length;j++) {
            var action=actionFactory.createObject(canvas,{action:actions[j]});
            add(actions[j],action,action.iconNormalizer);
        }
        var file=Qt.resolvedUrl("Plugin/Icons/tray/flclash.svg");
        var tray=trayFactory.createObject(canvas,{modelData:{id:"FlClash",icon:file}});
        add("FlClash",tray,null);
        var lazycat=trayFactory.createObject(canvas,{modelData:{id:"lzc-client-desktop_status_icon_1",icon:file}});
        add("懒猫",lazycat,null);
        // Validate every SVG override using the same native glyph adapter.
        var symbols=["󰂯","󰤨","","󰍺"];
        var filenames=["bluetooth","network","audio","monitors"];
        for(var k=0;k<symbols.length;k++) {
            var symbol=symbols[k]; var map={}; map[symbol]="widgets/"+filenames[k]+".svg";
            var glyph=buttonFactory.createObject(canvas,{text:symbol,fontFamily:"JetBrainsMono Nerd Font"});
            var rasterizer=rasterizerFactory.createObject(canvas,{rootItem:glyph,glyphFiles:map});
            var n=normalizerFactory.createObject(canvas,{sourceItem:glyph,targetSize:16});
            glyph.layer.enabled=true; glyph.layer.textureSize=Qt.size(128,128);
            glyph.layer.sourceRect=Qt.binding(function(value){return function(){return value.sourceRect;};}(n));
            glyph.layer.effect=effectFactory;
            add(filenames[k],glyph,n);
        }
        var generic=trayFactory.createObject(canvas,{modelData:{id:"example-app",icon:Qt.resolvedUrl("generic-tray.svg")}});
        add("托盘首字母",generic,generic.iconNormalizer);
        add("时间",clockFactory.createObject(canvas, {displayDate: new Date(2026, 9, 10, 23, 59)}),null);
    }
    Timer {
        id: capture
        interval: 1000; running: true
        onTriggered: {
            root.pending=entries.length;
            for(var i=0;i<entries.length;i++) {
                var entry=entries[i];
                console.log("ICON_METRIC",entry.name,JSON.stringify(entry.normalizer?entry.normalizer.snapshot()
                    :typeof entry.source.snapshot === "function" ? entry.source.snapshot() : {}));
                entry.item.grabToImage(function(index, phase){return function(result){
                    if(!result.saveToFile(Quickshell.env("ICON_PREVIEW_DIR")+"/"+index+"-"+phase+".png")) root.failed=true;
                    root.pending--;
                    if(!root.pending) {
                        if(root.phase===2) { console.log(root.failed?"ICON_FAIL":"ICON_PASS"); Qt.quit(); }
                        else { root.phase++;
                            if(root.phase===1) {
                                testHost.recording=true; testHost.stayAwake=true; testHost.doNotDisturb=true;
                                for(var q=0;q<entries.length;q++) root.switchInputMode(entries[q].source);
                            }
                            else for(var q=0;q<entries.length;q++) {
                                var source = entries[q].source;
                                if ("magnification" in source) {
                                    source.magnification = 1.28;
                                    entries[q].item.width = source.implicitWidth;
                                    entries[q].item.height = source.implicitHeight;
                                } else source.scale=1.28;
                            }
                            capture.restart();
                        }
                    }
                };}(i,root.phase),Qt.size(Math.round(entry.item.width*(i === 19 ? 1 : 4)),
                    Math.round(entry.item.height*(i === 19 ? 1 : 4))));
            }
        }
    }
    Timer { interval: 10000; running: true; onTriggered: {console.log("ICON_TIMEOUT");Qt.quit();} }
}
