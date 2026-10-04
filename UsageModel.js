// Stable identities and pure-data persistence; never save QML object references.
function countFor(counts, key) {
    var value = counts && Object.prototype.hasOwnProperty.call(counts, key) ? counts[key] : 0;
    return typeof value === "number" && isFinite(value) && value >= 0
        ? Math.min(Math.floor(value), Number.MAX_SAFE_INTEGER) : 0;
}

function decode(text) {
    if (!String(text || "").trim()) return {};
    var data = JSON.parse(text);
    if (!data || data.version !== 1 || !data.counts || typeof data.counts !== "object" || Array.isArray(data.counts))
        throw new Error("Unsupported click-count file");
    var counts = {};
    Object.keys(data.counts).forEach(function(key) {
        if (/^(widget|tray|action):.+/.test(key)) counts[key] = countFor(data.counts, key);
    });
    return counts;
}

function increment(counts, key) {
    var next = Object.assign({}, counts);
    next[key] = Math.min(countFor(counts, key) + 1, Number.MAX_SAFE_INTEGER);
    return next;
}

function trayKey(item) {
    var id = String(item && (item.id || item.title || item.tooltipTitle) || "").trim();
    // GTK's instance suffix can change when the application is restarted.
    id = id.replace(/_status_icon_\d+$/, "_status_icon");
    return id ? "tray:" + id : "";
}

function rank(cells, counts) {
    return cells.filter(function(cell) { return cell && cell.height > 0; }).slice().sort(function(a, b) {
        var aPower = a.usageKey === "action:power";
        var bPower = b.usageKey === "action:power";
        if (aPower !== bPower) return aPower ? -1 : 1;
        return countFor(counts, b.usageKey) - countFor(counts, a.usageKey) || a.ordinal - b.ordinal;
    });
}

if (typeof module !== "undefined") module.exports = {
    countFor: countFor, decode: decode, increment: increment, trayKey: trayKey, rank: rank
};
