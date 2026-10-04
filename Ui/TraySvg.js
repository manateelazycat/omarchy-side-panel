// Trace grayscale regions into vector contours; SVGs contain no bitmap data.
function hash(text) {
    var value = 2166136261;
    for (var i = 0; i < text.length; i++) value = Math.imul(value ^ text.charCodeAt(i), 16777619);
    return (value >>> 0).toString(16);
}
function packagedFile(id, source) {
    if (/flclash/i.test(id)) return "tray/flclash.svg";
    return /lzc-client|lazycat|懒猫/i.test(id) ? "glyphs/4c-43.svg" : "";
}
function simplify(points, epsilon) {
    if (points.length <= 2) return points;
    var a = points[0], b = points[points.length - 1], best = 0, index = 0;
    var dx = b[0] - a[0], dy = b[1] - a[1], length = dx * dx + dy * dy;
    for (var i = 1; i < points.length - 1; i++) {
        var p = points[i], t = length ? Math.max(0, Math.min(1, ((p[0]-a[0])*dx+(p[1]-a[1])*dy)/length)) : 0;
        var distance = Math.pow(p[0]-a[0]-t*dx, 2) + Math.pow(p[1]-a[1]-t*dy, 2);
        if (distance > best) { best = distance; index = i; }
    }
    if (best <= epsilon * epsilon) return [a, b];
    return simplify(points.slice(0, index + 1), epsilon).slice(0, -1).concat(simplify(points.slice(index), epsilon));
}
function contourPath(mask, width, height) {
    var edges = new Map();
    function edge(x1, y1, x2, y2) {
        var start = y1 * (width + 1) + x1, end = y2 * (width + 1) + x2;
        if (!edges.has(start)) edges.set(start, []);
        edges.get(start).push(end);
    }
    for (var y = 0; y < height; y++) for (var x = 0; x < width; x++) {
        var p = y * width + x;
        if (!mask[p]) continue;
        if (y === 0 || !mask[p-width]) edge(x,y,x+1,y);
        if (x === width-1 || !mask[p+1]) edge(x+1,y,x+1,y+1);
        if (y === height-1 || !mask[p+width]) edge(x+1,y+1,x,y+1);
        if (x === 0 || !mask[p-1]) edge(x,y+1,x,y);
    }
    var result = "";
    while (edges.size) {
        var first = edges.keys().next().value, cursor = first, points = [];
        do {
            points.push([cursor % (width+1), Math.floor(cursor/(width+1))]);
            var next = edges.get(cursor);
            if (!next) break;
            cursor = next.pop(); if (!next.length) edges.delete(points[points.length-1][1]*(width+1)+points[points.length-1][0]);
        } while (cursor !== first && points.length <= width*height*4);
        if (points.length < 4) continue;
        var split = 1, farthest = 0;
        for (var j = 1; j < points.length; j++) {
            var distance = Math.pow(points[j][0]-points[0][0],2)+Math.pow(points[j][1]-points[0][1],2);
            if (distance > farthest) { farthest = distance; split = j; }
        }
        points = simplify(points.slice(0,split+1),.65).slice(0,-1)
            .concat(simplify(points.slice(split).concat([points[0]]),.65).slice(0,-1));
        if (points.length < 3) continue;
        var n = points.length;
        function mid(a,b) { return [(a[0]+b[0])/2,(a[1]+b[1])/2]; }
        var start = mid(points[n-1],points[0]); result += "M"+start.join(" ");
        for (var k = 0; k < n; k++) {
            var previous = points[(k+n-1)%n], point = points[k], nextPoint = points[(k+1)%n], end = mid(point,nextPoint);
            var ax=point[0]-previous[0], ay=point[1]-previous[1], bx=nextPoint[0]-point[0], by=nextPoint[1]-point[1];
            var cosine=(ax*bx+ay*by)/Math.sqrt((ax*ax+ay*ay)*(bx*bx+by*by));
            result += cosine > .6 ? "Q"+point.join(" ")+" "+end.join(" ") : "L"+point.join(" ")+"L"+end.join(" ");
        }
        result += "Z";
    }
    return result;
}
function trace(data, width, height) {
    var paths = "", count = width*height, gray = new Uint8Array(count), opaque = new Uint8Array(count);
    for (var i = 0; i < count; i++) {
        opaque[i] = data[i*4+3] >= 32 ? 1 : 0;
        gray[i] = Math.round(data[i*4]*.299 + data[i*4+1]*.587 + data[i*4+2]*.114);
    }
    for (var level = 0; level <= 255; level += 17) {
        var mask = new Uint8Array(count);
        for (var j = 0; j < count; j++) mask[j] = opaque[j] && gray[j] >= level ? 1 : 0;
        var d = contourPath(mask,width,height);
        if (d) paths += '<path fill="rgb('+level+','+level+','+level+')" fill-rule="evenodd" d="'+d+'"/>';
    }
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 '+width+' '+height+'">'+paths+'</svg>\n';
}
if (typeof module !== "undefined") module.exports = {hash: hash, packagedFile: packagedFile, trace: trace};
