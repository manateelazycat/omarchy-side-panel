const test = require('node:test');
const assert = require('node:assert/strict');
const model = require('../TrayIconModel.js');

test('tray initials use names before numeric SNI identifiers', () => {
  assert.equal(model.initial({id: '1', title: 'wechat'}), 'W');
  assert.equal(model.initial({id: '2', tooltipTitle: 'flclash'}), 'F');
  assert.equal(model.initial({id: 'lzc-client', title: '懒猫微服'}), 'L');
  assert.equal(model.initial({title: 'θ'}), 'Θ');
  assert.equal(model.initial({title: '微信'}), '微');
  assert.equal(model.initial({}), '?');
});

test('transparent frames ignore invisible RGB and identical bitmap updates stay identical', () => {
  const blank = model.frame([255, 10, 20, 0, 3, 4, 5, 0]);
  assert.equal(blank.blank, true);
  assert.equal(blank.signature, model.frame([0, 0, 0, 0, 100, 90, 80, 0]).signature);
  const icon = [20, 80, 120, 255, 10, 20, 30, 255];
  assert.equal(model.frame(icon).blank, false);
  assert.equal(model.frame(icon).signature, model.frame(icon.slice()).signature);
  assert.notEqual(model.frame(icon).signature, model.frame([20, 80, 121, 255, 10, 20, 30, 255]).signature);
});
