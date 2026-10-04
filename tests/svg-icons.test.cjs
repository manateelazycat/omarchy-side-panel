const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const glyphs = require('../Icons/Glyphs.js');
const {trace,packagedFile} = require('../Ui/TraySvg.js');
const {options} = require('../SidePanelModel.js');

test('SVG rendering keeps the existing icon size and pixel mode remains optional', () => {
  assert.equal(options({}).iconSize,28);
  assert.equal(options({}).pixelated,false);
  assert.equal(options({sidePanel:{pixelated:true}}).pixelated,true);
});

test('every generated glyph has real vector paths and no bitmap or font dependency', () => {
  for (const key of glyphs.available) {
    const svg = fs.readFileSync(path.join(__dirname,'../Icons/glyphs',key+'.svg'),'utf8');
    assert.match(svg,/<path /);
    assert.doesNotMatch(svg,/<image|<text|data:image/);
  }
  for (const text of ['󰐥','󰓛','󰂛','󰂚','▦','EN','中']) assert.ok(glyphs.fileFor(text));
});

test('tray apps use their selected marks and new icons produce standalone grayscale SVGs', () => {
  for (const state of [1,2,3]) assert.equal(packagedFile('FlClash','image://icon/status_'+state+'.png'),'tray/flclash.svg');
  assert.equal(packagedFile('lzc-client-desktop_status_icon_1','image://pixmap/1'),'tray/lazycat.svg');
  assert.equal(packagedFile('another app','image://pixmap/2'),'');
  for (const name of ['flclash.svg','lazycat.svg']) {
    const artwork = fs.readFileSync(path.join(__dirname,'../Icons/tray',name),'utf8');
    assert.match(artwork,/<path /);
    assert.doesNotMatch(artwork,/<image|data:image/);
    for (const color of artwork.matchAll(/(?:fill|stroke)="rgb\((\d+),(\d+),(\d+)\)"/g)) {
      assert.equal(color[1],color[2]);
      assert.equal(color[2],color[3]);
    }
  }
  const pixels = new Uint8Array(8*8*4);
  for (let y=1;y<7;y++) for (let x=1;x<7;x++) {
    const i=(y*8+x)*4;
    pixels[i]=250;pixels[i+1]=80;pixels[i+2]=20;pixels[i+3]=255;
  }
  const svg=trace(pixels,8,8);
  assert.match(svg,/viewBox="0 0 8 8"/);
  assert.match(svg,/<path/);
  assert.doesNotMatch(svg,/<image|data:image/);
  for (const match of svg.matchAll(/rgb\((\d+),(\d+),(\d+)\)/g)) assert.ok(match[1]===match[2]&&match[2]===match[3]);
  assert.doesNotMatch(trace(new Uint8Array(8*8*4),8,8),/<path/);
});
