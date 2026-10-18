const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const vm = require('node:vm');
const landscape = vm.createContext({});
vm.runInContext(readFileSync(join(__dirname, 'contents/ui/landscape.js'), 'utf8'), landscape);

test('source and output bounds preserve portrait, ultrawide and 8K screen proportions', () => {
  for (const [width, height] of [[1280, 720], [1920, 1080], [7680, 4320], [3440, 1440], [1080, 1920], [12000, 800], [0, 0]]) {
    for (const cell of [2, 4, 20]) {
      const grid = landscape.grid(width, height, cell);
      const source = landscape.sourceSize(width, height);
      assert.ok(grid.columns >= 1 && grid.columns <= 960 && grid.rows >= 1 && grid.rows <= 600);
      assert.ok(source.columns >= 1 && source.columns <= 1600 && source.rows >= 1 && source.rows <= 1000);
      if (width && height) {
        for (const size of [grid, source])
          assert.ok(Math.abs(size.columns / size.rows / (width / height) - 1) < 0.03);
      }
    }
  }
});

test('fine output reveals substantially more source samples; source density stays fixed', () => {
  assert.equal(landscape.grid(1280, 720, 2).columns, 640);
  assert.equal(landscape.grid(1280, 720, 10).columns, 128);
  const source = landscape.sourceSize(1280, 720);
  assert.equal(source.columns, 1280);
  assert.equal(source.rows, 720);
  assert.deepEqual(landscape.sourceSize(1280, 720), landscape.sourceSize(3840, 2160));
});

test('weather grades warm pixels toward cool muted cloud and terrain tones', () => {
  const cloudy = landscape.gradePixel(230, 96, 73, 1, false);
  const rainy = landscape.gradePixel(230, 96, 73, 2, false);
  assert.ok(cloudy[0] < 230 && rainy[0] < cloudy[0]);
  const sum = a => a.reduce((total, channel) => total + channel, 0);
  assert.ok(sum(rainy) < sum(cloudy));
  for (const weather of [1, 2]) {
    const cloud = landscape.gradePixel(230, 96, 73, weather, true);
    assert.ok(Math.max(...cloud) - Math.min(...cloud) < 30);
  }
});

test('oversized cloud drift covers the view throughout its bounded oscillation', () => {
  for (const time of [0, 12, 200, 1000, 10000]) {
    const rect = landscape.cloudPlacement(1280, 720, time);
    assert.ok(rect.x <= 0 && rect.y <= 0);
    assert.ok(rect.x + rect.width >= 1280 && rect.y + rect.height >= 720);
  }
});

test('clock scales weather speed and bounds suspend/resume gaps', () => {
  assert.equal(landscape.advance(4, 0.05, 10), 4.05);
  assert.equal(landscape.advance(4, 0.05, 20), 4.1);
  assert.equal(landscape.advance(4, 20, 10), 4.1);
  assert.equal(landscape.advance(4, -1, 10), 4);
});
