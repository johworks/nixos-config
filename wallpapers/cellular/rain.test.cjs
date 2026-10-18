const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const vm = require('node:vm');
const rain = vm.createContext({});
vm.runInContext(readFileSync(join(__dirname, 'contents/ui/rain.js'), 'utf8'), rain);
const snapshot = world => JSON.stringify(world.drops);
const close = (actual, expected) => assert.ok(Math.abs(actual - expected) < 1e-12, `${actual} != ${expected}`);

test('births have independent positions and attributes, initially spread through the view', () => {
  const samples = [0.1, 0.2, 0.3, 0.4, 0.5, 0.9, 0.8, 0.7, 0.6, 0.1];
  let reads = 0;
  const world = rain.create(() => samples[reads++]);
  rain.setIntensity(world, 2 / 240);
  const [first, second] = world.drops;
  assert.equal(reads, 10);
  close(first.x, -0.04 + 0.1 * 1.08);
  close(first.y, -0.04 + 0.2 * 1.08);
  close(second.y, -0.04 + 0.8 * 1.08);
  for (const key of ['x', 'y', 'speed', 'length', 'opacity']) assert.notEqual(first[key], second[key]);
});

test('motion is continuous without RNG reads, zero wind is vertical and reversal preserves position', () => {
  let reads = 0;
  const world = rain.create(() => { reads++; return 0.5; });
  rain.setIntensity(world, 1 / 240);
  const drop = world.drops[0], startX = drop.x, startY = drop.y;
  rain.advance(world, 0.05, 0, 1280, 720);
  close(drop.x, startX);
  close(drop.y, startY + drop.speed * 0.05);
  rain.advance(world, 0.05, 1, 1280, 720);
  assert.ok(drop.x > startX);
  rain.advance(world, 0.05, -1, 1280, 720);
  close(drop.x, startX);
  assert.equal(reads, 5);
  assert.equal(world.drops[0], drop);
  const stopped = snapshot(world);
  rain.advance(world, 0, 1, 1280, 720);
  rain.advance(world, -10, 1, 1280, 720);
  assert.equal(snapshot(world), stopped);
  // A suspend gap cannot advance by more than the fastest scene tick (0.2s).
  const y = drop.y;
  rain.advance(world, 100, 0, 1280, 720);
  close(drop.y, y + drop.speed * 0.2);
});

test('each offscreen respawn consumes new independent values instead of wrapping its trajectory', () => {
  const values = [0.1, 0.2, 0.3, 0.4, 0.5, 0.9, 0.8, 0.7, 0.6, 0.1, 0.3, 0.4, 0.1, 0.2, 0.9];
  let reads = 0;
  const world = rain.create(() => values[reads++]);
  rain.setIntensity(world, 1 / 240);
  const first = world.drops[0];
  first.y = 1.039;
  rain.advance(world, 0.05, 0, 1280, 720);
  const second = world.drops[0];
  assert.equal(reads, 10);
  assert.notEqual(first, second);
  close(second.x, -0.04 + 0.9 * 1.08);
  close(second.y, -0.02 - 0.8 * 0.12);
  for (const key of ['x', 'speed', 'length', 'opacity']) assert.notEqual(first[key], second[key]);
  second.x = 1.039;
  rain.advance(world, 0.1, 1, 720, 1280);
  assert.equal(reads, 15, 'side exit also receives a fresh birth');
  close(world.drops[0].x, -0.04 + 0.3 * 1.08);
  assert.ok(world.drops[0].y < 0);
});

test('intensity adapts bounded density without resetting survivors and painting consumes no randomness', () => {
  let reads = 0;
  const world = rain.create(() => { reads++; return 0.5; });
  rain.setIntensity(world, 0.5);
  const first = world.drops[0];
  rain.advance(world, 0.1, 0, 1280, 720);
  const y = first.y;
  rain.setIntensity(world, 0.7);
  assert.equal(world.drops.length, 168);
  assert.equal(reads, 168 * 5);
  assert.equal(world.drops[0], first);
  close(first.y, y);
  rain.setIntensity(world, 0.2);
  assert.equal(world.drops.length, 48);
  assert.equal(world.drops[0], first);
  const paths = [];
  const ctx = { beginPath() {}, moveTo(x,y) { paths.push([x,y]); }, lineTo(x,y) { paths.push([x,y]); }, stroke() {} };
  const stored = snapshot(world), before = reads;
  rain.draw(ctx, 1280, 720, world, 0);
  for (let i = 0; i < paths.length; i += 2) assert.equal(paths[i][0], paths[i+1][0]);
  paths.length = 0;
  rain.draw(ctx, 1280, 720, world, -1);
  for (let i = 0; i < paths.length; i += 2) assert.ok(paths[i+1][0] < paths[i][0]);
  assert.equal(snapshot(world), stored);
  assert.equal(reads, before, 'repaints cannot rerandomize particles');
  rain.setIntensity(world, 10);
  assert.equal(world.drops.length, 240);
  rain.setIntensity(world, 0);
  paths.length = 0;
  rain.draw(ctx, 1280, 720, world, 1);
  assert.equal(paths.length, 0);
  rain.setIntensity(world, -1);
  assert.equal(world.drops.length, 0);
});

test('seeded simulations reproduce lifecycles, remain bounded and own separate RNG state', () => {
  const first = rain.create(rain.seededRandom(73)), second = rain.create(rain.seededRandom(73));
  rain.setIntensity(first, 1);
  rain.setIntensity(second, 1);
  assert.equal(snapshot(first), snapshot(second));
  for (let step = 0; step < 1000; step++) {
    const wind = step % 3 - 1;
    for (const world of [first, second]) rain.advance(world, 0.1, wind, 720, 1280);
    for (const drop of first.drops) {
      assert.ok(drop.x >= -0.04 && drop.x <= 1.04);
      assert.ok(drop.y >= -0.14 && drop.y <= 1.04);
      assert.ok(drop.speed >= 0.28 && drop.speed < 0.44);
      assert.ok(drop.length >= 0.009 && drop.length < 0.018);
      assert.ok(drop.opacity >= 0.3 && drop.opacity < 0.6);
    }
  }
  assert.equal(snapshot(first), snapshot(second));
  const frozen = snapshot(second);
  rain.advance(first, 0.1, 0, 720, 1280);
  assert.equal(snapshot(second), frozen);
});
