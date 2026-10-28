// Positions and lengths are fractions of the view, independent of the grid.
// Each scene owns its particles and RNG; painting never consumes randomness.
var maximumDrops = 240;
function seededRandom(seed) {
    var value = Number(seed) >>> 0;
    return function () {
        value = (value * 1664525 + 1013904223) >>> 0;
        return value / 4294967296;
    };
}
function create(random) {
    return { random: random || Math.random, drops: [] };
}
function spawn(random, initial) {
    return {
        x: -0.04 + random() * 1.08,
        // Populate the initial view; later births start above the visible top.
        y: initial ? -0.04 + random() * 1.08 : -0.02 - random() * 0.12,
        speed: 0.28 + random() * 0.16,
        length: 0.009 + random() * 0.009,
        opacity: 0.3 + random() * 0.3
    };
}
function setIntensity(world, intensity) {
    var count = Math.ceil(maximumDrops * Math.max(0, Math.min(1, intensity)));
    while (world.drops.length > count) world.drops.pop();
    while (world.drops.length < count) world.drops.push(spawn(world.random, true));
}
function advance(world, seconds, wind, width, height) {
    // The scene already bounds elapsed time/speed; retain the same upper bound
    // here so a caller cannot turn a resume gap into an unbounded simulation.
    var step = Math.max(0, Math.min(0.2, seconds));
    if (!step) return;
    var drift = Math.max(-1, Math.min(1, wind)) * 0.32;
    var aspect = Math.max(1, height) / Math.max(1, width);
    for (var i = 0; i < world.drops.length; i++) {
        var drop = world.drops[i];
        drop.y += drop.speed * step;
        drop.x += drop.speed * step * drift * aspect;
        // Respawn only once fully outside; never wrap a visible trajectory.
        if (drop.y > 1.04 || drop.x < -0.04 || drop.x > 1.04)
            world.drops[i] = spawn(world.random, false);
    }
}
function draw(ctx, width, height, world, wind) {
    ctx.lineWidth = Math.max(0.8, width / 1280);
    for (var i = 0; i < world.drops.length; i++) {
        var drop = world.drops[i], length = drop.length * height;
        ctx.strokeStyle = "rgba(179,203,220," + drop.opacity + ")";
        ctx.beginPath();
        ctx.moveTo(drop.x * width, drop.y * height);
        ctx.lineTo(drop.x * width + wind * length * 0.32, drop.y * height + length);
        ctx.stroke();
    }
}
