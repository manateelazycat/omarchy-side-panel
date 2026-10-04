function alphaBounds(data, width, height, threshold) {
    var left = width, top = height, right = -1, bottom = -1;
    for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
            if (data[(y * width + x) * 4 + 3] >= threshold) {
                left = Math.min(left, x); top = Math.min(top, y);
                right = Math.max(right, x); bottom = Math.max(bottom, y);
            }
        }
    }
    return right < left ? null : {x: left, y: top, width: right - left + 1, height: bottom - top + 1};
}

function sourceRect(bounds, width, height, targetSize) {
    if (!bounds || targetSize <= 0) return {x: 0, y: 0, width: 0, height: 0};
    var ratio = Math.max(bounds.width, bounds.height) / targetSize;
    var cropWidth = width * ratio, cropHeight = height * ratio;
    return {x: bounds.x + bounds.width / 2 - cropWidth / 2,
        y: bounds.y + bounds.height / 2 - cropHeight / 2,
        width: cropWidth, height: cropHeight};
}

if (typeof module !== "undefined") module.exports = {alphaBounds: alphaBounds, sourceRect: sourceRect};
