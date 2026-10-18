const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const vm = require('node:vm');
const controls = vm.createContext({});
vm.runInContext(readFileSync(join(__dirname, 'contents/ui/controls.js'), 'utf8'), controls);

test('one normalized state clamps endpoints and supplies practical missing/invalid defaults', () => {
  const state = controls.normalize({Brightness: 999, Warmth: -300, SunX: -4, SunY: 120,
    SunStrength: NaN, CloudAmount: 0, CloudDarkness: 200, Wind: -500, RainIntensity: -1});
  assert.equal(state.brightness, 1.5);
  assert.equal(state.warmth, -1);
  assert.equal(state.sunX, 0);
  assert.equal(state.sunY, 1);
  assert.equal(state.sunStrength, 1);
  assert.equal(state.cloudAmount, 0);
  assert.equal(state.cloudDarkness, 1);
  assert.equal(state.wind, -1);
  assert.equal(state.rain, 0);
  assert.equal(controls.normalize({Wind: 0, RainIntensity: 37}).wind, 0);
  assert.equal(controls.normalize({Wind: 0, RainIntensity: 37}).rain, 0.37);
});

test('presets preserve global settings and manual edits remain independent', () => {
  const target = {CellSize: 3, Speed: 8, Paused: true};
  controls.writePreset(target, 'rainy');
  target.Brightness = 123;
  target.SunStrength = 76;
  target.Wind = 0;
  const state = controls.normalize(target);
  assert.equal(state.brightness, 1.23);
  assert.equal(state.sunStrength, 0.76);
  assert.equal(state.rain, 1);
  assert.equal(state.wind, 0);
  assert.equal(target.CellSize, 3);
  assert.equal(target.Speed, 8);
  assert.equal(target.Paused, true);
});

test('legacy Weather migrates once, then stored independent edits survive reload and legacy changes', () => {
  for (const [Weather, expected] of [[0, 'sunny'], [1, 'cloudy'], [2, 'rainy']]) {
    const saved = {Weather, ControlsVersion: 0, CellSize: 4, Speed: 7, Paused: true};
    assert.equal(controls.migrate(saved), true);
    for (const key of controls.keys) assert.equal(saved[key], controls.preset(expected)[key]);
    saved.Brightness = 114;
    saved.Wind = -32;
    saved.RainIntensity = 17;
    saved.Weather = 0;
    const reloaded = JSON.parse(JSON.stringify(saved));
    assert.equal(controls.migrate(reloaded), false);
    assert.deepEqual(reloaded, saved);
  }
});

test('context and prefixed presets commit version last after reset and survive later reloads', () => {
  for (const prefix of ['', 'cfg_']) {
    const saved = {
      [prefix + 'Weather']: 0, [prefix + 'ControlsVersion']: 0,
      [prefix + 'CellSize']: 3, [prefix + 'Speed']: 7, [prefix + 'Paused']: true,
    };
    const writes = [];
    const target = new Proxy(saved, {
      set(object, key, value) { writes.push(key); object[key] = value; return true; },
    });
    controls.writePreset(target, 'rainy', prefix);
    assert.equal(saved[prefix + 'ControlsVersion'], 1);
    assert.deepEqual(writes, [...controls.keys].map(key => prefix + key).concat(prefix + 'ControlsVersion'));
    let reloaded = JSON.parse(JSON.stringify(saved));
    assert.equal(controls.migrate(reloaded, prefix), false);
    assert.deepEqual(reloaded, saved, 'chosen preset survives reload despite legacy Sunny');
    reloaded[prefix + 'Brightness'] = 123;
    reloaded[prefix + 'Wind'] = -42;
    const edited = JSON.parse(JSON.stringify(reloaded));
    reloaded = JSON.parse(JSON.stringify(edited));
    assert.equal(controls.migrate(reloaded, prefix), false);
    assert.deepEqual(reloaded, edited, 'later custom edits survive reload');
    assert.equal(reloaded[prefix + 'CellSize'], 3);
    assert.equal(reloaded[prefix + 'Speed'], 7);
    assert.equal(reloaded[prefix + 'Paused'], true);
  }
});
