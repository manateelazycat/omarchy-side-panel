const test = require('node:test');
const assert = require('node:assert/strict');
const {alphaBounds, sourceRect} = require('../Ui/IconGeometry.js');

test('ignores transparent padding and faint pixels around an asymmetric icon', () => {
  const pixels = new Uint8Array(8 * 6 * 4);
  pixels[3] = 12;
  for (let y = 1; y < 5; y++) for (let x = 3; x < 5; x++) {
    pixels[(y * 8 + x) * 4 + 3] = 255;
  }
  assert.deepEqual(alphaBounds(pixels, 8, 6, 32), {x: 3, y: 1, width: 2, height: 4});
  assert.equal(alphaBounds(new Uint8Array(8 * 6 * 4), 8, 6, 32), null);
});

test('different glyphs and padded images have the same longest side without stretching', () => {
  for (const bounds of [
    {x: 9, y: 8, width: 9, height: 11},
    {x: 1, y: 3, width: 14, height: 10},
    {x: 5, y: 6, width: 6, height: 4},
  ]) {
    const crop = sourceRect(bounds, 28, 27, 16);
    const paintedWidth = bounds.width * 28 / crop.width;
    const paintedHeight = bounds.height * 27 / crop.height;
    assert.ok(Math.abs(Math.max(paintedWidth, paintedHeight) - 16) < 1e-9);
    assert.ok(Math.abs(paintedWidth / paintedHeight - bounds.width / bounds.height) < 1e-9);
    assert.ok(Math.abs((bounds.x + bounds.width / 2 - crop.x) * 28 / crop.width - 14) < 1e-9);
    assert.ok(Math.abs((bounds.y + bounds.height / 2 - crop.y) * 27 / crop.height - 13.5) < 1e-9);
  }
});

test('empty or unmeasured icons keep the native layer rectangle', () => {
  assert.deepEqual(sourceRect(null, 28, 27, 16), {x: 0, y: 0, width: 0, height: 0});
});
