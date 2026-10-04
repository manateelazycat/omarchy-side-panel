function name(item) {
    return String(item && (item.title || item.tooltipTitle || item.id) || "").trim();
}

function initial(item) {
    var names = item ? [item.title, item.tooltipTitle, item.id] : [];
    for (var i = 0; i < names.length; i++) {
        var letter = String(names[i] || "").match(/[a-z]/i);
        if (letter) return letter[0].toUpperCase();
    }
    return (Array.from(name(item))[0] || "?").toUpperCase();
}

// Compare rendered content, not image:// URLs: SNI bridges can publish the
// same bitmap repeatedly under fresh URLs without actually blinking.
function frame(pixels) {
    var hash = 2166136261;
    var blank = true;
    for (var i = 0; i < pixels.length; i += 4) {
        var alpha = pixels[i + 3];
        if (alpha > 8) blank = false;
        for (var channel = 0; channel < 4; channel++) {
            var value = channel === 3 ? alpha : alpha > 8 ? pixels[i + channel] : 0;
            hash = Math.imul(hash ^ value, 16777619) >>> 0;
        }
    }
    return {signature: blank ? "blank" : hash.toString(16), blank: blank};
}

if (typeof module !== "undefined") module.exports = {name: name, initial: initial, frame: frame};
