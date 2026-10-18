const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const vm = require('node:vm');

const landscape = vm.createContext({});
vm.runInContext(readFileSync(join(__dirname, 'contents/ui/landscape.js'), 'utf8'), landscape);

function frame(scene, weather, time = 0, width = 320, height = 180) {
  const pixels = new Uint32Array(width * height);
  let calls = 0;
  const context = {
    fillStyle: '#000000',
    fillRect(x, y, w, h) {
      assert.ok([x, y, w, h].every(Number.isInteger), 'all layers snap to integer grid pixels');
      assert.ok(w >= 0 && h >= 0);
      calls++;
      const color = Number.parseInt(this.fillStyle.slice(1), 16);
      for (let row = Math.max(0, y); row < Math.min(height, y + h); row++) {
        pixels.fill(color, row * width + Math.max(0, Math.min(width, x)),
          row * width + Math.max(0, Math.min(width, x + w)));
      }
    },
  };
  landscape.render(context, width, height, scene, weather, time);
  return { pixels, calls };
}

function count(frame, hex) {
  const color = Number.parseInt(hex.slice(1), 16);
  return frame.pixels.filter(pixel => pixel === color).length;
}

test('grid adds fine detail, caps both dimensions, and preserves screen shape', () => {
  assert.ok(landscape.grid(1920, 1080, 4).columns > landscape.grid(1920, 1080, 12).columns);
  for (const [width, height] of [[1920, 1080], [7680, 4320], [3440, 1440], [1080, 1920], [12000, 800], [0, 0]]) {
    const grid = landscape.grid(width, height, 2);
    assert.ok(grid.columns >= 1 && grid.columns <= 480);
    assert.ok(grid.rows >= 1 && grid.rows <= 300);
    if (width && height) {
      assert.ok(Math.abs(grid.columns / grid.rows / (width / height) - 1) < 0.03);
      for (const scene of [0, 1]) {
        const result = frame(scene, 2, 12, grid.columns, grid.rows);
        assert.ok(result.calls < 12000, 'bounded drawing work');
        assert.ok(result.pixels.every(pixel => pixel !== 0), 'no exposed background after resize');
      }
    }
  }
});

test('each landscape has distinctive terrain and all three weather palettes', () => {
  const signatures = new Set();
  for (const scene of [0, 1]) {
    for (const weather of [0, 1, 2]) {
      const result = frame(scene, weather);
      const p = landscape.palettes[weather];
      assert.ok(count(result, p.sky[0]) > 5000);
      assert.ok(count(result, p.cloud[0]) > 100);
      assert.ok(count(result, p.leaf) > 100);
      if (weather === 0) assert.ok(count(result, p.sun) > 500);
      else assert.equal(count(result, p.sun), 0);
      if (scene === 1) {
        assert.ok(count(result, p.snow) > 500);
        assert.ok(count(result, p.water) > 3000);
      } else {
        assert.ok(count(result, p.grass) > 4000);
        assert.ok(count(result, p.trunk) > 50);
      }
      signatures.add(Buffer.from(result.pixels.buffer).toString('base64'));
      assert.deepEqual(result.pixels, frame(scene, weather).pixels, 'repeat paint is deterministic');
    }
  }
  assert.equal(signatures.size, 6);
});

test('clouds drift while terrain stays fixed; rain moves across the foreground', () => {
  for (const scene of [0, 1]) {
    for (const weather of [0, 1]) {
      const start = frame(scene, weather).pixels;
      const later = frame(scene, weather, 8).pixels;
      assert.notDeepEqual(start.slice(0, 320 * 70), later.slice(0, 320 * 70));
      assert.deepEqual(start.slice(320 * 120), later.slice(320 * 120));
    }
    const start = frame(scene, 2).pixels;
    const later = frame(scene, 2, 0.1).pixels;
    assert.notDeepEqual(start.slice(320 * 120), later.slice(320 * 120));
  }
});

test('clock scales motion continuously and bounds suspend/resume gaps', () => {
  assert.equal(landscape.advance(4, 0.05, 10), 4.05);
  assert.equal(landscape.advance(4, 0.05, 20), 4.1);
  assert.equal(landscape.advance(4, 20, 10), 4.1);
  assert.equal(landscape.advance(4, -1, 10), 4);
});
