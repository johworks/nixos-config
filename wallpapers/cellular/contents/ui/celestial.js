// Approximate UTC/J2000 sky, deliberately separate from animation. See SKY.md.
var radians = Math.PI / 180;
function mod(value, period) { return ((value % period) + period) % period; }
function clamp(value, low, high) { return Math.max(low, Math.min(high, value)); }
function sidereal(now) {
    var jd = now / 86400000 + 2440587.5;
    var midnight = Math.floor(jd - 0.5) + 0.5;
    var hours = (jd - midnight) * 24;
    var centuries = (jd - 2451545) / 36525;
    return mod(6.697375 + 0.065709824279 * (midnight - 2451545)
        + 1.0027379 * hours + 0.0000258 * centuries * centuries, 24);
}
function horizontal(ra, dec, now, latitude, longitude) {
    var hour = ((sidereal(now) - ra) * 15 + longitude) * radians;
    var d = dec * radians, lat = latitude * radians;
    var east = -Math.cos(d) * Math.sin(hour);
    var north = Math.sin(d) * Math.cos(lat) - Math.cos(d) * Math.cos(hour) * Math.sin(lat);
    var up = Math.sin(d) * Math.sin(lat) + Math.cos(d) * Math.cos(hour) * Math.cos(lat);
    return { east: east, north: north, up: up,
        altitude: Math.asin(clamp(up, -1, 1)) / radians,
        azimuth: mod(Math.atan2(east, north) / radians, 360) };
}
function project(vector, width, height) {
    if (width <= 0 || height <= 0 || vector.up < 0) return null;
    // True west, elevation 30 degrees, horizontal FOV 110 degrees. West's
    // screen-right is north; vector projection avoids azimuth seam wrapping.
    var pitch = 30 * radians;
    var depth = -vector.east * Math.cos(pitch) + vector.up * Math.sin(pitch);
    if (depth <= 0) return null;
    var tangent = Math.tan(55 * radians);
    var x = 0.5 + vector.north / (2 * depth * tangent);
    var y = 0.5 - (vector.east * Math.sin(pitch) + vector.up * Math.cos(pitch))
        / (2 * depth * tangent * height / width);
    return x >= 0 && x <= 1 && y >= 0 && y <= 1 ? { x: x, y: y } : null;
}
function phase(now) {
    // NASA published new moon, 2026-01-18 19:52 UTC; mean synodic month.
    return mod((now - Date.UTC(2026, 0, 18, 19, 52)) / (29.530588 * 86400000), 1);
}
function illumination(value) { return (1 - Math.cos(value * 2 * Math.PI)) / 2; }
function phaseName(value) {
    return ["New", "Waxing crescent", "First quarter", "Waxing gibbous", "Full",
        "Waning gibbous", "Last quarter", "Waning crescent"][Math.floor(mod(value, 1) * 8 + 0.5) % 8];
}
function darkness(altitude) {
    var value = clamp((-altitude - 2) / 10, 0, 1);
    return value * value * (3 - 2 * value);
}
function transmission(amount, dark) { return 1 - amount * (0.45 + 0.55 * dark); }
function drawMoon(ctx, width, height, state) {
    var lit = illumination(state.phase);
    if (lit < 0.005 || state.moonStrength <= 0) return;
    var radius = 25 * Math.min(width / 1280, height / 720);
    var x = state.moonX * width, y = state.moonY * height;
    ctx.globalAlpha = state.fade * state.moonStrength;
    var halo = ctx.createRadialGradient(x, y, radius * 0.8, x, y, radius * 2.6);
    halo.addColorStop(0, "rgba(225,230,240," + (0.12 * lit) + ")");
    halo.addColorStop(1, "rgba(225,230,240,0)");
    ctx.fillStyle = halo;
    ctx.fillRect(x - radius * 3, y - radius * 3, radius * 6, radius * 6);
    ctx.fillStyle = "#e9e7d6";
    var cosine = Math.cos(2 * Math.PI * state.phase);
    // Orthographic sphere terminator: waxing illuminated on the right,
    // waning on the left. This is a screen convention, not limb orientation.
    for (var row = Math.ceil(-radius); row < radius; row++) {
        var half = Math.sqrt(Math.max(0, radius * radius - (row + 0.5) * (row + 0.5)));
        var left = state.phase < 0.5 ? cosine * half : -half;
        var right = state.phase < 0.5 ? half : -cosine * half;
        ctx.fillRect(x + left, y + row, right - left, 1);
    }
    ctx.globalAlpha = 1;
}
function draw(ctx, width, height, state, stars) {
    ctx.reset();
    if (!state || state.fade <= 0) return 0;
    var count = 0, scale = Math.min(width / 1280, height / 720);
    if (state.starStrength > 0 && state.place) {
        ctx.fillStyle = "#e7edf7";
        for (var i = 0; i < stars.length; i++) {
            var star = stars[i];
            var point = project(horizontal(star[1], star[2], state.now, state.place.latitude, state.place.longitude), width, height);
            if (!point) continue;
            count++;
            ctx.globalAlpha = state.fade * state.starStrength * clamp(Math.pow(10, -0.15 * (star[3] - 1)), 0.22, 1);
            var size = (star[3] < 1 ? 2.8 : star[3] < 2.5 ? 2.2 : 1.5) * scale;
            ctx.fillRect(point.x * width - size / 2, point.y * height - size / 2, size, size);
        }
    }
    drawMoon(ctx, width, height, state);
    ctx.globalAlpha = 1;
    return count;
}
