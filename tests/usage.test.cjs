const test = require('node:test');
const assert = require('node:assert/strict');
const usage = require('../UsageModel.js');

test('pins the power menu first and ranks remaining icons by count with stable ties', () => {
  const cells = [
    {usageKey: 'action:power', ordinal: 0, height: 40},
    {usageKey: 'tray:FlClash', ordinal: 1, height: 40},
    {usageKey: 'widget:audio', ordinal: 2, height: 40},
    {usageKey: 'action:reload', ordinal: 3, height: 40},
    {usageKey: 'widget:hidden', ordinal: 4, height: 0},
  ];
  const counts = {'tray:FlClash': 7, 'widget:audio': 7, 'action:reload': 10, 'widget:hidden': 100};
  assert.deepEqual(usage.rank(cells, counts), [cells[0], cells[3], cells[1], cells[2]]);
  assert.equal(usage.rank([cells[3], cells[2], cells[1], cells[0]],
    usage.decode(JSON.stringify({version: 1, counts})))[0], cells[0]);
  assert.equal(cells[0].usageKey, 'action:power');
});

test('increments and restores counts by identity across icon changes and restarts', () => {
  const first = usage.increment({}, 'widget:omarchy.audio');
  const saved = JSON.stringify({version: 1, counts: first});
  const restored = usage.decode(saved);
  assert.equal(usage.increment(restored, 'widget:omarchy.audio')['widget:omarchy.audio'], 2);
  assert.equal(first['widget:omarchy.audio'], 1);
  assert.equal(usage.trayKey({id: 'lzc-client-desktop_status_icon_1', icon: 'old.png'}),
    usage.trayKey({id: 'lzc-client-desktop_status_icon_9', icon: 'new.png'}));
  assert.notEqual(usage.trayKey({id: 'FlClash'}), usage.trayKey({id: 'Steam'}));
});

test('rejects corrupt or unsupported data and sanitizes stored counters', () => {
  assert.deepEqual(usage.decode(''), {});
  assert.throws(() => usage.decode('{'));
  assert.throws(() => usage.decode('{"version":2,"counts":{}}'));
  assert.throws(() => usage.decode('{"version":1,"counts":[]}'));
  assert.deepEqual(usage.decode(JSON.stringify({version: 1, counts: {
    'widget:negative': -4, 'widget:string': '20', 'tray:fraction': 2.9,
    'action:huge': 1e30, unrelated: 99,
  }})), {'widget:negative': 0, 'widget:string': 0, 'tray:fraction': 2, 'action:huge': Number.MAX_SAFE_INTEGER});
});
