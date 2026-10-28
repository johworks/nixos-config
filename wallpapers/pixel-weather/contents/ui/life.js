// Wrap both edges so patterns can travel across the desktop.
function create(columns, rows, random) {
    var count = columns * rows;
    var world = {
        columns: columns,
        rows: rows,
        cells: new Uint8Array(count),
        next: new Uint8Array(count),
        age: new Uint8Array(count),
        trail: new Uint8Array(count),
        quiet: 0
    };
    var density = 0.22 + random() * 0.13;
    var symmetric = random() < 0.4;
    for (var y = 0; y < rows; ++y) {
        for (var x = 0; x < columns; ++x) {
            var index = y * columns + x;
            var mirror = y * columns + columns - x - 1;
            world.cells[index] = symmetric && x >= columns / 2
                ? world.cells[mirror] : Number(random() < density);
            world.age[index] = world.cells[index];
        }
    }
    return world;
}

function step(world) {
    var columns = world.columns;
    var rows = world.rows;
    var changed = false;
    var periodTwoChanged = false;
    for (var y = 0; y < rows; ++y) {
        var above = ((y + rows - 1) % rows) * columns;
        var below = ((y + 1) % rows) * columns;
        var row = y * columns;
        for (var x = 0; x < columns; ++x) {
            var left = (x + columns - 1) % columns;
            var right = (x + 1) % columns;
            var index = row + x;
            var neighbors = world.cells[above + left] + world.cells[above + x]
                + world.cells[above + right] + world.cells[row + left]
                + world.cells[row + right] + world.cells[below + left]
                + world.cells[below + x] + world.cells[below + right];
            var alive = Number(neighbors === 3 || (world.cells[index] && neighbors === 2));
            changed = changed || alive !== world.cells[index];
            // Before swapping, the spare buffer still holds the previous generation.
            periodTwoChanged = periodTwoChanged || alive !== world.next[index];
            world.next[index] = alive;
            world.age[index] = alive ? Math.min(world.age[index] + 1, 15) : 0;
            world.trail[index] = alive ? 8 : Math.max(0, world.trail[index] - 1);
        }
    }
    var previous = world.cells;
    world.cells = world.next;
    world.next = previous;
    world.quiet = !changed || !periodTwoChanged ? world.quiet + 1 : 0;
}
