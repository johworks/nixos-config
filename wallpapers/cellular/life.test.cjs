const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const vm = require('node:vm');

const life = vm.createContext({ Uint8Array });
vm.runInContext(readFileSync(join(__dirname, 'contents/ui/life.js'), 'utf8'), life);

function worldWith(points, size = 8) {
  const world = life.create(size, size, () => 1);
  for (const [x, y] of points) world.cells[y * size + x] = 1;
  return world;
}

function points(world) {
  return Array.from(world.cells.entries())
    .filter(([, alive]) => alive)
    .map(([i]) => [i % world.columns, Math.floor(i / world.columns)]);
}

test('a block survives and is recognized as quiet', () => {
  const block = [[2, 2], [3, 2], [2, 3], [3, 3]];
  const world = worldWith(block);
  for (let i = 0; i < 12; i++) life.step(world);
  assert.deepEqual(points(world), block);
  assert.equal(world.quiet, 12);
});

test('a blinker oscillates and is recognized as quiet', () => {
  const blinker = [[2, 3], [3, 3], [4, 3]];
  const world = worldWith(blinker);
  life.step(world);
  assert.deepEqual(points(world), [[3, 2], [3, 3], [3, 4]]);
  life.step(world);
  assert.deepEqual(points(world), blinker);
  assert.equal(world.quiet, 1);
});

test('a glider moves diagonally through both wrapped edges', () => {
  const world = worldWith([[7, 6], [0, 7], [6, 0], [7, 0], [0, 0]]);
  for (let i = 0; i < 4; i++) life.step(world);
  assert.deepEqual(points(world), [[1, 0], [0, 1], [1, 1], [7, 1], [0, 7]]);
  assert.equal(world.quiet, 0);
});

test('dead cells leave trails that fade away', () => {
  const world = worldWith([[3, 3]]);
  world.trail[27] = 8;
  life.step(world);
  assert.equal(world.cells[27], 0);
  assert.equal(world.trail[27], 7);
  for (let i = 0; i < 8; i++) life.step(world);
  assert.ok(world.trail.every(value => value === 0));
});

test('random seeds produce different worlds', () => {
  const first = life.create(80, 45, Math.random);
  const second = life.create(80, 45, Math.random);
  assert.notDeepEqual(first.cells, second.cells);
  assert.ok(first.cells.some(value => value === 1));
  assert.ok(first.cells.some(value => value === 0));
});
