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

test('lighting and cloud grades interpolate continuously instead of selecting looks', () => {
  const sums=[];
  for (const brightness of [0, 0.25, 0.5, 0.75, 1, 1.5]) {
    const pixel=landscape.gradePixel(230,96,73,brightness,0,false,0);
    sums.push(pixel.reduce((a,b)=>a+b,0));
  }
  for (let i=1;i<sums.length;i++) assert.ok(sums[i]>sums[i-1]);
  const colors=new Set();
  for (const warmth of [-1,-0.5,0,0.5,1])
    colors.add(JSON.stringify(landscape.gradePixel(230,96,73,1,warmth,false,0)));
  assert.equal(colors.size,5);
  const light=landscape.gradePixel(230,96,73,1,-1,true,0);
  const dark=landscape.gradePixel(230,96,73,1,-1,true,1);
  assert.ok(dark[0]<light[0] && Math.max(...dark)-Math.min(...dark)<24);
});

test('cloud crossfades cover the view with continuous wrap weights in either direction', () => {
  for (const phase of [-10000,0,12,75,200,1000,10000]) {
    const layers=landscape.cloudPlacements(1280,720,phase);
    assert.ok(Math.abs(layers[0].opacity+layers[1].opacity-1)<1e-10);
    for (const rect of layers) {
      assert.ok(rect.x<=0 && rect.y<=0);
      assert.ok(rect.x+rect.width>=1280 && rect.y+rect.height>=720);
    }
  }
  for (const phase of [10,70,150,220,310]) {
    const before=landscape.cloudPlacements(1280,720,phase);
    const after=landscape.cloudPlacements(1280,720,phase+0.01);
    for(let i=0;i<2;i++)
      if(before[i].opacity>0.01 && after[i].opacity>0.01) assert.ok(after[i].x>before[i].x);
  }
});

test('clock scales weather speed and bounds suspend/resume gaps', () => {
  assert.equal(landscape.advance(4, 0.05, 10), 4.05);
  assert.equal(landscape.advance(4, 0.05, 20), 4.1);
  assert.equal(landscape.advance(4, 20, 10), 4.1);
  assert.equal(landscape.advance(4, -1, 10), 4);
});
