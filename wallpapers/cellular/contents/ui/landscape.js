// Pure, deterministic grid renderer shared by Plasma and the offscreen preview.
function grid(width, height, cellSize) {
    var cell = Math.max(2, Math.min(20, cellSize || 4));
    var columns = Math.max(1, Math.ceil(width / cell));
    var rows = Math.max(1, Math.ceil(height / cell));
    var limit = Math.max(1, columns / 480, rows / 300);
    return { columns: Math.max(1, Math.round(columns / limit)),
             rows: Math.max(1, Math.round(rows / limit)) };
}

function advance(time, seconds, speed) {
    // Avoid a jump after suspend or a stalled frame. Speed changes motion, not FPS.
    return time + Math.max(0, Math.min(0.1, seconds)) * Math.max(1, Math.min(20, speed)) / 10;
}

var palettes = [
    { sky: ["#77b5c8", "#a7d0cc", "#e4dfb1"], sun: "#fff0b0", halo: "#d9d9ac",
      cloud: ["#fff2d3", "#e3dfce"], far: "#8aa6a0", mountain: "#768f91", face: "#a8b7ac",
      snow: "#f3ebd1", snowShade: "#c9d7cb", hill: "#77966b", grass: "#9fb269", shade: "#78934f",
      front: "#4d7051", trunk: "#645747", leaf: "#527f50", light: "#8fa958", leafShade: "#3c6550",
      water: "#88b6af", ripple: "#c7d5b2", flower: "#eddaa0" },
    { sky: ["#829ba9", "#a9bbc1", "#cbd2ca"], sun: "#e2e5cf", halo: "#b8c4c3",
      cloud: ["#e5e8e0", "#aebbc1"], far: "#849a9f", mountain: "#677f8d", face: "#92a5ab",
      snow: "#e1e7e3", snowShade: "#bacbd2", hill: "#6f8f7b", grass: "#8ba27c", shade: "#66856c",
      front: "#45665b", trunk: "#50504c", leaf: "#4f7867", light: "#839b73", leafShade: "#385c55",
      water: "#7e9fa9", ripple: "#b5c6c8", flower: "#c8cdb3" },
    { sky: ["#475b70", "#687c8b", "#97a69e"], sun: "#b6c1bd", halo: "#84959a",
      cloud: ["#6d7d8b", "#4c5e73"], far: "#647c84", mountain: "#4b6474", face: "#6f8892",
      snow: "#b9ccd1", snowShade: "#91aab8", hill: "#526f68", grass: "#6c886e", shade: "#4e7062",
      front: "#344f4e", trunk: "#424b4b", leaf: "#3c615a", light: "#65836a", leafShade: "#2e4c4c",
      water: "#5c7e8c", ripple: "#8aa6b0", flower: "#a6b6a6" }
];

function render(ctx, columns, rows, scene, weather, time) {
    var p = palettes[weather] || palettes[0];
    // A centered 320 x 180 composition extends into wide/tall screens. One scale
    // for both axes keeps trees, sun and peaks in proportion on every monitor.
    var scale = Math.min(columns / 320, rows / 180);
    var viewWidth = columns / scale;
    var viewHeight = rows / scale;
    var left = (320 - viewWidth) / 2;
    var top = 180 - viewHeight;

    function rect(x, y, w, h, color) {
        var x1 = Math.round((x - left) * scale);
        var y1 = Math.round((y - top) * scale);
        var x2 = Math.round((x + w - left) * scale);
        var y2 = Math.round((y + h - top) * scale);
        ctx.fillStyle = color;
        ctx.fillRect(x1, y1, Math.max(1, x2 - x1), Math.max(1, y2 - y1));
    }
    function ellipse(cx, cy, rx, ry, color) {
        var start = Math.round((cy - ry - top) * scale);
        var end = Math.round((cy + ry - top) * scale);
        for (var y = start; y <= end; y++) {
            var dy = ((y + 0.5) / scale + top - cy) / ry;
            if (Math.abs(dy) >= 1) continue;
            var half = rx * Math.sqrt(1 - dy * dy);
            rect(cx - half, y / scale + top, half * 2, 1 / scale, color);
        }
    }
    function polygon(points, color) {
        var minY = rows, maxY = 0;
        var pts = points.map(function (point) {
            var y = (point[1] - top) * scale;
            minY = Math.min(minY, y); maxY = Math.max(maxY, y);
            return [(point[0] - left) * scale, y];
        });
        ctx.fillStyle = color;
        for (var y = Math.max(0, Math.floor(minY)); y < Math.min(rows, Math.ceil(maxY)); y++) {
            var crossings = [];
            for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
                var a = pts[i], b = pts[j];
                if ((a[1] > y + 0.5) !== (b[1] > y + 0.5))
                    crossings.push(a[0] + (y + 0.5 - a[1]) * (b[0] - a[0]) / (b[1] - a[1]));
            }
            crossings.sort(function (a, b) { return a - b; });
            for (var k = 0; k + 1 < crossings.length; k += 2) {
                var x = Math.round(crossings[k]);
                ctx.fillRect(x, y, Math.max(1, Math.round(crossings[k + 1]) - x), 1);
            }
        }
    }
    function hill(base, amplitude, phase, color) {
        for (var x = 0; x < columns; x++) {
            var worldX = x / scale + left;
            var y = base + Math.sin(worldX / 66 + phase) * amplitude + Math.sin(worldX / 113 + phase) * amplitude * 0.4;
            ctx.fillStyle = color;
            var pixelY = Math.max(0, Math.round((y - top) * scale));
            if (pixelY < rows)
                ctx.fillRect(x, pixelY, 1, rows - pixelY);
        }
    }
    function pine(x, y, size, color) {
        rect(x - size * 0.06, y - size * 0.4, size * 0.12, size * 0.4, p.trunk);
        polygon([[x, y - size], [x + size * 0.27, y - size * 0.35], [x + size * 0.15, y - size * 0.35],
                 [x + size * 0.37, y - size * 0.12], [x - size * 0.37, y - size * 0.12],
                 [x - size * 0.15, y - size * 0.35], [x - size * 0.27, y - size * 0.35]], color);
    }
    // Broad sky bands retain a deliberate limited-palette pixel-art look.
    ctx.fillStyle = p.sky[0]; ctx.fillRect(0, 0, columns, rows);
    rect(left, 44, viewWidth, 40, p.sky[1]);
    rect(left, 84, viewWidth, 96, p.sky[2]);
    if (weather === 0) {
        ellipse(246, 36, 21, 21, p.halo);
        ellipse(246, 36, 15, 15, p.sun);
    }
    var cloudCount = weather === 0 ? 3 : weather === 1 ? 7 : 9;
    for (var c = 0; c < cloudCount; c++) {
        var span = viewWidth + 100;
        var cx = left - 50 + ((c * 83 + time * (0.9 + c % 3 * 0.15)) % span);
        var cy = 18 + (c * 17 % 49);
        var size = weather === 0 ? 0.75 : 1.1;
        ellipse(cx, cy + 4, 29 * size, 7 * size, p.cloud[1]);
        ellipse(cx - 12 * size, cy, 12 * size, 9 * size, p.cloud[0]);
        ellipse(cx + 3 * size, cy - 3, 17 * size, 12 * size, p.cloud[0]);
        ellipse(cx + 20 * size, cy + 1, 12 * size, 7 * size, p.cloud[0]);
    }
    if (scene === 1) {
        hill(113, 9, 2, p.far);
        polygon([[left - 20, 135], [37, 65], [65, 91], [119, 30], [168, 89], [205, 58], [289, 131], [left + viewWidth + 20, 140]], p.mountain);
        polygon([[119, 30], [168, 89], [192, 111], [142, 94], [126, 65]], p.face);
        polygon([[205, 58], [289, 131], [235, 114], [214, 85]], p.face);
        polygon([[89, 66], [119, 30], [146, 63], [131, 58], [123, 69], [113, 54], [104, 65]], p.snow);
        polygon([[119, 30], [146, 63], [131, 58], [123, 69], [126, 52]], p.snowShade);
        polygon([[189, 78], [205, 58], [225, 80], [208, 74], [202, 82], [199, 74]], p.snow);
        hill(129, 8, 0, p.hill);
        rect(left, 142, viewWidth, 38, p.water);
        for (var r = 0; r < 18; r++)
            rect(31 + r * 19 % 260, 146 + r * 7 % 29, 6 + r % 5 * 2, 1, p.ripple);
        polygon([[left, 131], [34, 143], [82, 155], [107, 180], [left, 180]], p.front);
        polygon([[254, 170], [279, 148], [left + viewWidth, 137], [left + viewWidth, 180], [224, 180]], p.front);
        pine(30, 155, 39, p.leafShade); pine(54, 165, 30, p.leaf);
        pine(284, 157, 32, p.leafShade); pine(303, 154, 43, p.leaf);
    } else {
        hill(110, 11, 2, p.far);
        hill(128, 15, 0.3, p.hill);
        hill(147, 19, 2.9, p.grass);
        // The little tree sits on the foreground hill; its silhouette is fixed.
        ellipse(124, 128, 23, 3, p.shade);
        polygon([[115, 129], [119, 105], [114, 91], [119, 90], [123, 105], [128, 98], [131, 100], [124, 114], [124, 130]], p.trunk);
        ellipse(109, 88, 17, 12, p.leafShade);
        ellipse(129, 86, 18, 14, p.leaf);
        ellipse(117, 76, 20, 14, p.leaf);
        ellipse(107, 75, 13, 8, p.light);
        ellipse(123, 68, 10, 5, p.light);
        ellipse(139, 82, 10, 6, p.light);
        // Sparse fixed meadow marks, never a random reseed on resize or repaint.
        for (var f = 0; f < 46; f++) {
            var fx = left + (f * 71 % 317) / 317 * viewWidth;
            var fy = 151 + f * 13 % 26;
            rect(fx, fy, 1, 2, p.shade);
            if (f % 4 === 0) rect(fx, fy - 1, 2, 1, p.flower);
        }
        hill(182, 12, 0.7, p.front);
    }
    if (weather === 2) {
        // Deterministic particles wrap in grid coordinates and share the scene clock.
        var drops = Math.min(180, Math.ceil(columns * rows / 700));
        for (var d = 0; d < drops; d++) {
            var dy = (d * 61.7 + time * 62) % (viewHeight + 12) - 6 + top;
            var dx = left + ((d * 97.3 + time * 9) % (viewWidth + 12)) - 6;
            rect(dx, dy, 1 / scale, 3 / scale, d % 3 === 0 ? p.ripple : p.sky[1]);
        }
    }
}
