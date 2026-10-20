import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('../assets/keyboard.js', import.meta.url), 'utf8');

function page(mode = 'B2') {
  let now = 100, flush, report;
  const listeners = new Map();
  const elements = Object.fromEntries(['prompt', 'second', 'editor', 'counter', 'run']
    .map(id => [id, { id, value: '', textContent: '', focus() {} }]));
  vm.runInNewContext(source, {
    URLSearchParams, location: { search: `?run=unit-test&mode=${mode}` },
    performance: { now: () => now },
    document: {
      getElementById: id => elements[id], activeElement: elements.prompt,
      addEventListener: (name, callback) => listeners.set(name, callback),
    },
    setInterval: callback => { flush = callback; },
    fetch: async (_url, options) => { report = JSON.parse(options.body); },
  });
  return {
    key(timeStamp, observedAt, repeat = false, metaKey = false) {
      now = observedAt;
      const event = {
        timeStamp, code: 'Escape', repeat, metaKey, shiftKey: true,
        target: elements.prompt, isTrusted: true, defaultPrevented: false,
        preventDefault() { this.defaultPrevented = true; },
      };
      listeners.get('keydown')(event);
      return event;
    },
    async snapshot() { await flush(); return report; },
  };
}

test('same event timestamp has separate arrival times without suppressing B2', async () => {
  const p = page();
  p.key(42, 110);
  const duplicate = p.key(42, 110.75);
  const s = await p.snapshot();
  assert.equal(s.keydowns, 2);
  assert.equal(s.duplicates, 1);
  assert.equal(s.recent[1].sincePreviousMs, 0.75);
  assert.equal(s.recent[1].sinceFirstMs, 0.75);
  assert.equal(s.recent[1].timestamp, 42);
  assert.equal(duplicate.defaultPrevented, false);
});

test('flood keeps first samples and bounds recent samples', async () => {
  const p = page();
  for (let i = 0; i < 300; i++) p.key(42, 110 + i);
  const s = await p.snapshot();
  assert.equal(s.duplicates, 299);
  assert.equal(s.firstKeydowns.length, 32);
  assert.equal(s.recent.length, 12);
  assert.equal(s.firstKeydowns[1].sinceFirstMs, 1);
  assert.equal(s.recent.at(-1).sinceFirstMs, 299);
  assert.equal(s.prevented, 0);
});

test('new presses and legitimate repeats stay distinct; E behavior is unchanged', async () => {
  const p = page();
  p.key(42, 110);
  p.key(43, 111);
  p.key(44, 112, true);
  const s = await p.snapshot();
  assert.equal(s.duplicates, 0);
  assert.equal(s.repeats, 1);
  const e = page('E');
  assert.equal(e.key(42, 110, false, true).defaultPrevented, true);
});
