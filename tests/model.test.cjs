const test = require('node:test');
const assert = require('node:assert/strict');
const model = require('../SidePanelModel.js');

test('keeps the existing right-side order and inline settings, excluding the duplicate monitor', () => {
  const entries = [{id: 'tray', pinned: ['steam']}, {id: 'crmne.hyprmoncfg'}, {id: 'omarchy.audio'}, {id: 'omarchy.monitor'}];
  assert.deepEqual(model.rightEntries({right: entries}), entries.slice(0, 3));
  assert.equal(entries.length, 4);
});
test('retains the standard monitor control when hyprmoncfg is absent', () => {
  assert.deepEqual(model.rightEntries({right: ['omarchy.audio', 'omarchy.monitor']}), ['omarchy.audio', 'omarchy.monitor']);
});
test('missing layout and horizontal spacers do not leave empty icon slots', () => {
  assert.deepEqual(model.rightEntries(null), []);
  assert.deepEqual(model.rightEntries({right: [{id: 'omarchy.spacer'}, {id: 'omarchy.audio'}]}), [{id: 'omarchy.audio'}]);
});
test('invalid and extreme settings keep the trigger and animation usable', () => {
  assert.equal(model.options({sidePanel: {triggerWidth: -20, iconSize: 200, hideDelay: 'bad'}}).triggerWidth, 1);
  assert.equal(model.options({sidePanel: {iconSize: 200}}).iconSize, 48);
  assert.equal(model.options({sidePanel: {hideDelay: 'bad'}}).hideDelay, 260);
});
test('fisheye interpolation is symmetric, bounded and continuous at the radius', () => {
  assert.equal(model.magnification(50, 50, 100, 1.28), 1.28);
  assert.equal(model.magnification(150, 50, 100, 1.28), 1);
  assert.equal(model.magnification(25, 50, 100, 1.28), model.magnification(75, 50, 100, 1.28));
  assert.ok(model.magnification(149.999, 50, 100, 1.28) - 1 < 1e-8);
});
