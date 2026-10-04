function entryId(entry) {
    return typeof entry === "string" ? entry : String(entry && entry.id || "");
}

function entrySettings(entry) {
    var settings = {};
    if (entry && typeof entry === "object") {
        for (var key in entry) if (key !== "id") settings[key] = entry[key];
    }
    return settings;
}

function tooltipLabel(id, metadata) {
    var labels = {
        "omarchy.agents": "AI 助手",
        "omarchy.bluetooth": "蓝牙",
        "omarchy.network": "网络",
        "omarchy.audio": "音量",
        "omarchy.power": "电池与电源",
        "omarchy.monitor": "显示器管理"
    };
    return labels[id] || String(metadata && (metadata.displayName || metadata.name) || "任务栏图标");
}

function rightEntries(layout) {
    var entries = layout && Array.isArray(layout.right) ? layout.right : [];
    var hasHyprmon = entries.some(function(entry) {
        return /(^|\.)hyprmon(cfg|config)$/.test(entryId(entry));
    });
    return entries.filter(function(entry) {
        var id = entryId(entry);
        return id !== "omarchy.spacer" && !(hasHyprmon && id === "omarchy.monitor");
    });
}

function numberSetting(settings, key, fallback, min, max) {
    var raw = settings && settings[key];
    var value = raw === undefined || raw === null ? fallback : Number(raw);
    return Math.max(min, Math.min(max, isFinite(value) ? value : fallback));
}

function options(config) {
    var settings = config && config.sidePanel || {};
    return {
        iconSize: numberSetting(settings, "iconSize", 28, 18, 48),
        pixelated: settings.pixelated !== false,
        iconPixels: Math.round(numberSetting(settings, "iconPixels", 16, 8, 24)),
        magnification: numberSetting(settings, "magnification", 1.28, 1, 1.6),
        triggerWidth: numberSetting(settings, "triggerWidth", 2, 1, 12),
        triggerHeight: numberSetting(settings, "triggerHeight", 120, 40, 400),
        showDelay: numberSetting(settings, "showDelay", 500, 150, 1500),
        hideDistance: numberSetting(settings, "hideDistance", 24, 8, 96),
        hideDelay: numberSetting(settings, "hideDelay", 260, 0, 1500),
        animationDuration: numberSetting(settings, "animationDuration", 300, 80, 1000)
    };
}

function magnification(pointerY, centerY, radius, maximum) {
    var distance = Math.abs(pointerY - centerY);
    if (distance >= radius) return 1;
    return 1 + (maximum - 1) * (1 + Math.cos(Math.PI * distance / radius)) / 2;
}

function serviceBridgeId(id) {
    return ["andy.language-switcher", "andy.display-reset",
        "io.github.manateelazycat.startup-map", "io.github.manateelazycat.power-awake"].indexOf(id) !== -1;
}

if (typeof module !== "undefined") module.exports = {
    entryId: entryId, entrySettings: entrySettings, tooltipLabel: tooltipLabel, rightEntries: rightEntries,
    options: options, magnification: magnification, serviceBridgeId: serviceBridgeId
};
