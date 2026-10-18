// Artwork uses a fixed design space. Output grid size never changes geometry.
function sizeWithin(width, height, maxWidth, maxHeight) {
    var w = Math.max(1, width), h = Math.max(1, height);
    var factor = Math.min(1, maxWidth / w, maxHeight / h);
    return { columns: Math.max(1, Math.round(w * factor)), rows: Math.max(1, Math.round(h * factor)) };
}
function grid(width, height, cellSize) {
    var cell = Math.max(2, Math.min(20, cellSize || 4));
    return sizeWithin(Math.ceil(width / cell), Math.ceil(height / cell), 960, 600);
}
function sourceSize(width, height) {
    // Stable source density at a given aspect, independent of desktop/detail size.
    var aspect = Math.max(1, width) / Math.max(1, height);
    return sizeWithin(Math.max(1280, 720 * aspect), Math.max(720, 1280 / aspect), 1600, 1000);
}
function advance(time, seconds, speed) {
    return time + Math.max(0, Math.min(0.1, seconds)) * Math.max(1, Math.min(20, speed)) / 10;
}
function mix(a, b, amount) {
    var value = "#";
    for (var c = 1; c < 7; c += 2) {
        var component = Math.round(parseInt(a.slice(c, c + 2), 16) * (1 - amount) + parseInt(b.slice(c, c + 2), 16) * amount);
        value += ("0" + component.toString(16)).slice(-2);
    }
    return value;
}
var palettes = [
    { sky: ["#628fa7", "#bfd4ce", "#f1e4bf"], sun: "#fff3bc", cloud: "#f6f0db", cloudShade: "#cbd6d0",
      haze: "#a6bcb7", rock: "#708d91", rockLight: "#b2b9aa", rockDark: "#4d6e7b", snow: "#f3eedd", snowShade: "#afc8cf",
      far: "#769891", hill: "#6d967c", grass: "#8caa65", grassLight: "#c1c180", grassDark: "#52784e",
      leaf: "#628b4d", leafLight: "#adc16a", leafDark: "#345e48", trunk: "#665346", water: "#6b9f9f", ripple: "#c7d4be", flower: "#f1d49b" },
    { sky: ["#728b9f", "#b6c7cc", "#d9ded2"], sun: "#dce0d3", cloud: "#e0e5e2", cloudShade: "#a4b1bc",
      haze: "#9eb3b6", rock: "#6e8796", rockLight: "#9caeb0", rockDark: "#4e697e", snow: "#e1e9e7", snowShade: "#a9c0cf",
      far: "#779496", hill: "#64857b", grass: "#819c79", grassLight: "#adba92", grassDark: "#506f5c",
      leaf: "#5b7f66", leafLight: "#94aa7e", leafDark: "#35574f", trunk: "#55544d", water: "#6b949f", ripple: "#b6cccd", flower: "#d5d5b5" },
    { sky: ["#40576d", "#788d99", "#b2beb6"], sun: "#bac6c2", cloud: "#738594", cloudShade: "#465c72",
      haze: "#849b9f", rock: "#526d80", rockLight: "#80979f", rockDark: "#354f67", snow: "#b9cdd1", snowShade: "#829eaf",
      far: "#607f84", hill: "#4e716b", grass: "#62846c", grassLight: "#91a58a", grassDark: "#3f6355",
      leaf: "#466b58", leafLight: "#768d70", leafDark: "#294c46", trunk: "#414b48", water: "#4e7788", ripple: "#96b2bb", flower: "#acbba9" }
];

// Smooth source geometry is intentionally sampled only after all layers compose.
function painter(ctx, width, height) {
    var s = Math.min(width / 1280, height / 720);
    var left = (1280 - width / s) / 2;
    var top = 720 - height / s;
    ctx.resetTransform();
    ctx.scale(s, s);
    ctx.translate(-left, -top);
    return {
        left: left, right: left + width / s, top: top,
        poly: function(points, color) {
            ctx.fillStyle = color; ctx.beginPath(); ctx.moveTo(points[0][0], points[0][1]);
            for (var i = 1; i < points.length; i++) ctx.lineTo(points[i][0], points[i][1]);
            ctx.closePath(); ctx.fill();
        },
        ellipse: function(x, y, rx, ry, color) {
            ctx.fillStyle = color; ctx.beginPath(); ctx.ellipse(x - rx, y - ry, rx * 2, ry * 2); ctx.fill();
        },
        line: function(points, color, width) {
            ctx.strokeStyle = color; ctx.lineWidth = width; ctx.lineCap = "round"; ctx.lineJoin = "round";
            ctx.beginPath(); ctx.moveTo(points[0][0], points[0][1]);
            for (var i = 1; i < points.length; i++) ctx.lineTo(points[i][0], points[i][1]);
            ctx.stroke();
        }
    };
}
function sky(ctx, width, height, weather) {
    ctx.reset();
    var p = palettes[weather] || palettes[0], art = painter(ctx, width, height);
    var gradient = ctx.createLinearGradient(0, art.top, 0, 490);
    gradient.addColorStop(0, p.sky[0]); gradient.addColorStop(0.62, p.sky[1]); gradient.addColorStop(1, p.sky[2]);
    ctx.fillStyle = gradient; ctx.fillRect(art.left, art.top, art.right - art.left, 720 - art.top);
    if (weather === 0) {
        var glow = ctx.createRadialGradient(1030, 125, 25, 1030, 125, 105);
        glow.addColorStop(0, "rgba(255,243,188,0.24)");
        glow.addColorStop(1, "rgba(255,243,188,0)");
        art.ellipse(1030, 125, 105, 105, glow);
        art.ellipse(1030, 125, 31, 31, p.sun);
    }
}
function hilltop(x) {
    return 430 + 0.055 * x + 0.00038 * x * x + Math.sin(x / 170) * 8;
}
function scenery(ctx, width, height, weather) {
    ctx.reset();
    var p = palettes[weather] || palettes[0], art = painter(ctx, width, height);
    var poly = art.poly, ellipse = art.ellipse, line = art.line;
    function pine(x, y, h, color) {
        line([[x, y], [x, y - h]], p.trunk, Math.max(0.8, h * 0.035));
        for (var tier = 0; tier < 5; tier++) {
            var ty = y - h + tier * h * 0.14;
            var spread = h * (0.08 + tier * 0.04);
            poly([[x, ty], [x + spread, ty + h * 0.32], [x + 2, ty + h * 0.25], [x - spread, ty + h * 0.32]], color);
            line([[x, ty + 2], [x - spread * 0.6, ty + h * 0.23]], mix(color, p.grassLight, 0.19), Math.max(0.7, h / 60));
        }
    }
    function mountain(x, y, w, h, distant) {
        var base = distant ? mix(p.rock, p.haze, 0.55) : p.rock;
        var light = distant ? mix(p.rockLight, p.haze, 0.6) : p.rockLight;
        var dark = distant ? mix(p.rockDark, p.haze, 0.55) : p.rockDark;
        poly([[x - w * 0.58, y + h], [x - w * 0.31, y + h * 0.46], [x - w * 0.22, y + h * 0.37],
              [x - w * 0.08, y + h * 0.12], [x, y], [x + w * 0.12, y + h * 0.17],
              [x + w * 0.2, y + h * 0.33], [x + w * 0.32, y + h * 0.46], [x + w * 0.59, y + h]], base);
        poly([[x, y], [x + w * 0.11, y + h * 0.43], [x + w * 0.06, y + h * 0.59],
              [x + w * 0.28, y + h * 0.92], [x + w * 0.59, y + h]], light);
        for (var ridge = 0; ridge < 8; ridge++) {
            var t = 0.2 + ridge * 0.085;
            var rx = x + w * (0.1 * t + Math.sin(ridge * 1.7) * 0.025);
            var ry = y + h * t;
            poly([[rx, ry], [x - w * (0.12 + t * 0.32), y + h * Math.min(1, t + 0.33)],
                  [x - w * (0.06 + t * 0.17), y + h * Math.min(1, t + 0.22)]], mix(base, dark, 0.42 + ridge % 3 * 0.15));
            poly([[rx + 4, ry + 9], [x + w * (0.16 + t * 0.29), y + h * Math.min(1, t + 0.4)],
                  [x + w * (0.12 + t * 0.24), y + h * Math.min(1, t + 0.43)]], mix(light, base, 0.28 + ridge % 2 * 0.25));
        }
        var snow = distant ? mix(p.snow, p.haze, 0.35) : p.snow;
        poly([[x - w * 0.22, y + h * 0.37], [x - w * 0.08, y + h * 0.12], [x, y],
              [x + w * 0.12, y + h * 0.17], [x + w * 0.2, y + h * 0.33],
              [x + w * 0.12, y + h * 0.28], [x + w * 0.1, y + h * 0.4],
              [x + w * 0.035, y + h * 0.26], [x + w * 0.005, y + h * 0.39],
              [x - w * 0.04, y + h * 0.22], [x - w * 0.09, y + h * 0.36],
              [x - w * 0.12, y + h * 0.28]], snow);
        poly([[x, y], [x + w * 0.12, y + h * 0.17], [x + w * 0.2, y + h * 0.33],
              [x + w * 0.12, y + h * 0.28], [x + w * 0.1, y + h * 0.4], [x + w * 0.035, y + h * 0.26]], p.snowShade);
        for (var channel = 0; channel < 4; channel++) {
            var cx = x - w * 0.025 - channel * w * 0.04;
            var cy = y + h * (0.27 + channel * 0.06);
            line([[cx, cy], [cx - w * 0.045, cy + h * 0.08], [cx - w * 0.08, cy + h * 0.22]], snow, 1.5 + channel * 0.6);
        }
    }
    // Receding ranges carry progressively more atmospheric color.
    mountain(430, 217, 420, 234, true);
    mountain(765, 124, 430, 340, true);
    mountain(1235, 195, 400, 280, true);
    mountain(665, 187, 490, 330, false);
    mountain(1000, 151, 500, 377, false);
    poly([[art.left, 411], [180, 381], [325, 408], [440, 394], [570, 430], [718, 405], [848, 441], [1013, 421], [1170, 442], [art.right, 408], [art.right, 720], [art.left, 720]], mix(p.far, p.haze, 0.28));
    poly([[art.left, 452], [215, 433], [407, 462], [615, 432], [784, 464], [1002, 451], [1124, 464], [art.right, 442], [art.right, 720], [art.left, 720]], p.far);
    // A forest belt follows the valley instead of filling the frame with noise.
    for (var tree = 0; tree < 155; tree++) {
        var tx = 390 + tree * 6.6;
        var ty = 458 + Math.sin(tx / 95) * 10 + tree % 4 * 3;
        pine(tx, ty, 12 + (tree * 7 % 17), mix(p.hill, p.rockDark, 0.12 + tree % 3 * 0.1));
    }
    poly([[art.left, 485], [380, 475], [530, 483], [656, 473], [810, 486], [973, 475], [1141, 491], [art.right, 466], [art.right, 720], [art.left, 720]], p.hill);
    // Lake opens toward the right, reflecting the pale mountain light.
    var lake = ctx.createLinearGradient(0, 480, 0, 720);
    lake.addColorStop(0, mix(p.water, p.haze, 0.5)); lake.addColorStop(1, p.water);
    poly([[740, 491], [932, 489], [1123, 505], [1055, 534], [1110, 565], [970, 615], [1050, 720], [560, 720], [664, 587], [835, 539], [680, 514]], lake);
    for (var reflection = 0; reflection < 82; reflection++) {
        var ry = 498 + reflection * 2.65;
        var rx = 830 + Math.sin(reflection * 2.2) * (20 + reflection * 1.35);
        line([[rx, ry], [rx + 5 + reflection % 9 * 3, ry]], mix(p.water, p.ripple, 0.17 + reflection % 4 * 0.11), 0.7 + reflection / 100);
    }
    line([[741, 490], [681, 514], [835, 539], [664, 587], [560, 720]], p.grassLight, 3);
    poly([[1120, 506], [1194, 490], [art.right, 486], [art.right, 720], [1050, 720], [971, 615], [1111, 564], [1057, 534]], mix(p.grass, p.hill, 0.7));
    for (var bank = 0; bank < 22; bank++) {
        var bx = 1160 + bank * 10;
        pine(bx, 520 + bank % 6 * 6, 14 + bank * 7 % 24, mix(p.leafDark, p.haze, 0.22));
    }
    // The foreground slope is built in broad, lit facets with contour seams.
    var slope = [[art.left, hilltop(art.left)]];
    for (var sx = art.left + 35; sx < 820; sx += 35) slope.push([sx, hilltop(sx)]);
    slope.push([850, 740], [art.left, 740]); poly(slope, p.grass);
    poly([[art.left, 506], [100, 496], [280, 531], [465, 600], [670, 720], [art.left, 720]], mix(p.grass, p.grassLight, 0.13));
    poly([[art.left, 627], [128, 594], [324, 631], [486, 720], [art.left, 720]], mix(p.grass, p.grassDark, 0.17));
    for (var contour = 0; contour < 7; contour++) {
        var points = [];
        for (var gx = art.left; gx < 780; gx += 17) points.push([gx, hilltop(gx) + 21 + contour * 36 + Math.sin(gx / 73 + contour) * 4]);
        line(points, mix(p.grass, contour % 2 ? p.grassLight : p.grassDark, 0.17), 1.2 + contour * 0.3);
    }
    // Fixed clusters of meadow tufts follow the contours, getting larger nearer us.
    for (var band = 0; band < 13; band++) {
        for (var tuft = 0; tuft < 51; tuft++) {
            var x = art.left + tuft * 19.7 + Math.sin(tuft * 3.1 + band) * 7;
            var y = hilltop(x) + 14 + band * 21 + Math.sin(tuft * 1.7 + band) * 9;
            if (y > 725 || x > 800) continue;
            var h = 1.5 + band * 0.3;
            var grass = tuft % 3 ? p.grassDark : p.grassLight;
            line([[x - 2, y], [x - 3, y - h], [x, y], [x + 2, y - h * 1.3]], mix(p.grass, grass, 0.5), 0.8 + band * 0.04);
            if ((tuft + band * 3) % 11 === 0) {
                ellipse(x, y - h - 1, 1.1 + band * 0.055, 0.8 + band * 0.04, p.flower);
                ellipse(x + 2.5, y - h + 1.5, 0.9, 0.7, mix(p.flower, p.grassLight, 0.45));
            }
        }
    }
    // A quiet winding footpath adds scale and leads the eye into the valley.
    poly([[460, 720], [435, 671], [425, 644], [383, 609], [377, 586], [359, 565], [353, 543], [348, 544], [352, 568], [365, 590], [369, 615], [405, 652], [406, 681], [421, 720]], mix(p.grassLight, p.trunk, 0.25));
    for (var stone = 0; stone < 34; stone++) {
        var kx = 18 + stone * 31 % 660;
        var ky = hilltop(kx) + 48 + stone * 29 % 190;
        if (ky > 705) continue;
        var sz = 2 + (ky - 430) / 90 + stone % 3;
        ellipse(kx + 2, ky + sz * 0.4, sz * 1.4, sz * 0.4, mix(p.grass, p.grassDark, 0.5));
        poly([[kx - sz, ky], [kx - sz * 0.6, ky - sz * 0.75], [kx + sz * 0.4, ky - sz], [kx + sz, ky], [kx, ky + sz * 0.3]], mix(p.rock, p.grassLight, 0.3));
        poly([[kx - sz, ky], [kx - sz * 0.6, ky - sz * 0.75], [kx, ky - sz * 0.2], [kx, ky + sz * 0.3]], p.rockLight);
    }
    // A small, characterful tree: structural branches show through leaf clusters.
    var baseX = 303, baseY = hilltop(baseX) + 2;
    ellipse(baseX + 28, baseY + 5, 73, 9, mix(p.grass, p.leafDark, 0.36));
    poly([[287, baseY + 2], [296, 453], [293, 421], [276, 389], [282, 385], [303, 416], [311, 452], [312, baseY]], p.trunk);
    poly([[303, baseY], [299, 451], [297, 425], [303, 435], [309, baseY]], mix(p.trunk, p.grassLight, 0.4));
    line([[303, 451], [321, 418], [349, 392], [356, 375]], p.trunk, 7);
    line([[299, 439], [271, 414], [251, 383]], p.trunk, 5);
    line([[301, 426], [307, 392], [298, 367]], p.trunk, 5);
    line([[321, 417], [337, 410], [366, 409]], p.trunk, 3);
    line([[277, 414], [258, 410], [234, 393]], p.trunk, 3);
    // Overlapping angular clusters model a canopy lit from the upper right.
    for (var leaf = 0; leaf < 95; leaf++) {
        var angle = leaf * 2.39996;
        var radius = Math.sqrt(leaf / 95);
        var lx = 300 + Math.cos(angle) * radius * 83;
        var ly = 365 + Math.sin(angle) * radius * 44 + Math.sin(lx / 33) * 6;
        var leafSize = 11 + leaf * 7 % 13;
        var lit = Math.max(0, Math.min(1, 0.5 + (lx - 300) / 240 - (ly - 365) / 110));
        var color = lit > 0.6 ? mix(p.leaf, p.leafLight, (lit - 0.4) * 1.2) : mix(p.leafDark, p.leaf, lit * 1.3);
        poly([[lx - leafSize, ly], [lx - leafSize * 0.6, ly - leafSize * 0.55], [lx + leafSize * 0.15, ly - leafSize * 0.7],
              [lx + leafSize, ly - leafSize * 0.15], [lx + leafSize * 0.7, ly + leafSize * 0.5], [lx - leafSize * 0.35, ly + leafSize * 0.65]], color);
        if (leaf % 3 === 0)
            line([[lx - 5, ly - leafSize * 0.35], [lx + 1, ly - leafSize * 0.45], [lx + 7, ly - leafSize * 0.2]], mix(color, p.leafLight, 0.35), 1.2);
    }
}
function clouds(ctx, width, height, weather, time) {
    var p = palettes[weather] || palettes[0], art = painter(ctx, width, height);
    var count = weather === 0 ? 4 : weather === 1 ? 9 : 11;
    var span = art.right - art.left + 280;
    for (var cloud = 0; cloud < count; cloud++) {
        var x = art.left - 140 + ((cloud * 291 + time * (3 + cloud % 3)) % span);
        var y = 67 + cloud * 31 % 146;
        var scale = weather === 0 ? 0.65 : 0.95;
        for (var lobe = 0; lobe < 9; lobe++) {
            var lx = x + (lobe - 4) * 20 * scale;
            var ly = y + Math.sin(lobe * 0.82) * 8 * scale;
            var radius = (17 + Math.sin(lobe * 1.1) * 8) * scale;
            art.ellipse(lx, ly + 8, radius * 1.5, radius * 0.6, p.cloudShade);
            art.ellipse(lx + 4, ly - 2, radius * 1.2, radius * 0.7, mix(p.cloudShade, p.cloud, 0.75 + lobe % 3 * 0.1));
        }
    }
}
function rain(ctx, width, height, weather, time) {
    if (weather !== 2) return;
    var p = palettes[2], art = painter(ctx, width, height);
    for (var drop = 0; drop < 260; drop++) {
        var x = art.left + ((drop * 127.7 + time * 31) % (art.right - art.left + 20)) - 10;
        var y = art.top + ((drop * 79.3 + time * 235) % (740 - art.top)) - 10;
        art.line([[x, y], [x + 1.6, y + 7 + drop % 3 * 2]], mix(p.sky[1], p.ripple, 0.3 + drop % 3 * 0.15), drop % 3 === 0 ? 1.3 : 0.8);
    }
}
