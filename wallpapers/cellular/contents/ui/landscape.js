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
var skies = [
    ["#754476", "#df6887", "#ffc982"],
    ["#53677f", "#9daab8", "#c9cbd0"],
    ["#2d4057", "#5a6c80", "#83939f"]
];
function sky(ctx, width, height, weather) {
    ctx.reset();
    var colors = skies[weather] || skies[0];
    var gradient = ctx.createLinearGradient(0, 0, 0, height * 0.72);
    gradient.addColorStop(0, colors[0]); gradient.addColorStop(0.48, colors[1]); gradient.addColorStop(1, colors[2]);
    ctx.fillStyle = gradient; ctx.fillRect(0, 0, width, height);
    if (weather === 0) {
        var x = width * 0.73, y = height * 0.34, radius = Math.min(width / 1280, height / 720) * 32;
        var glow = ctx.createRadialGradient(x, y, radius, x, y, radius * 3.6);
        glow.addColorStop(0, "rgba(255,224,132,0.4)"); glow.addColorStop(1, "rgba(255,224,132,0)");
        ctx.fillStyle = glow; ctx.fillRect(x - radius * 4, y - radius * 4, radius * 8, radius * 8);
        ctx.fillStyle = "#fff3ac"; ctx.beginPath(); ctx.ellipse(x - radius, y - radius, radius * 2, radius * 2); ctx.fill();
    }
}
function gradePixel(r, g, b, weather, cloud) {
    if (weather === 0) return [r, g, b];
    var light = r * 0.2126 + g * 0.7152 + b * 0.0722;
    if (cloud) {
        var value = weather === 1 ? 94 + light * 0.61 : 36 + light * 0.4;
        return [value * 0.94, value, value * 1.06];
    }
    var saturation = weather === 1 ? 0.26 : 0.17;
    var red = light * (1 - saturation) + r * saturation;
    var green = light * (1 - saturation) + g * saturation;
    var blue = light * (1 - saturation) + b * saturation;
    return weather === 1 ? [red * 0.81, green * 0.96, blue * 1.08] : [red * 0.57, green * 0.72, blue * 0.9];
}
function grade(ctx, width, height, weather, cloud) {
    if (weather === 0) return;
    // Read/process only when an asset, source size or weather changes. Alpha is
    // left intact, including translucent cloud wisps and canopy/sky boundaries.
    var image = ctx.getImageData(0, 0, width, height);
    var pixels = image.data;
    for (var i = 0; i < pixels.length; i += 4) {
        if (!pixels[i + 3]) continue;
        var color = gradePixel(pixels[i], pixels[i + 1], pixels[i + 2], weather, cloud);
        pixels[i] = color[0]; pixels[i + 1] = color[1]; pixels[i + 2] = color[2];
    }
    // Replace the source pixels rather than blending them over their old alpha.
    ctx.reset();
    // Qt requires the explicit dirty rectangle here; the short form was a no-op
    // on the installed runtime. Pixel tests cover the cached graded result.
    ctx.putImageData(image, 0, 0, 0, 0, width, height);
}
function asset(ctx, width, height, image, weather, cloud) {
    ctx.reset();
    // Fit the asset width, anchor terrain to the bottom, and extend the sky on
    // taller screens. Wide screens crop vertically without distorting artwork.
    // Both original project assets are 1672 x 941; keep that aspect intact.
    var artHeight = width * 941 / 1672;
    var y = cloud ? 0 : height - artHeight;
    ctx.drawImage(image, 0, y, width, artHeight);
    grade(ctx, width, height, weather, cloud);
}
function cloudPlacement(width, height, time) {
    return { x: -width * 0.06 + Math.sin(time / 75) * width * 0.04,
             y: -height * 0.06 + Math.sin(time / 110) * height * 0.01,
             width: width * 1.12, height: height * 1.12 };
}
function rain(ctx, width, height, weather, time) {
    if (weather !== 2) return;
    ctx.strokeStyle = "rgba(179,203,220,0.5)"; ctx.lineWidth = Math.max(0.8, width / 1280);
    ctx.beginPath();
    for (var drop = 0; drop < 240; drop++) {
        var x = ((drop * 127.7 + time * 31) % (width + 20)) - 10;
        var y = ((drop * 79.3 + time * 235) % (height + 20)) - 10;
        ctx.moveTo(x, y); ctx.lineTo(x + 1.6, y + 7 + drop % 3 * 2);
    }
    ctx.stroke();
}
