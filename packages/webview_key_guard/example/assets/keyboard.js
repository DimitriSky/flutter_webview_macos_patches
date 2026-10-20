const params = new URLSearchParams(location.search);
const run = params.get('run');
const mode = params.get('mode');
const seen = new Set();
const combinations = {};
const recent = [];
const firstKeydowns = [];
const arrivals = new Map();
const started = performance.now();
let keydowns = 0, duplicates = 0, repeats = 0, prevented = 0, inputs = 0;
let dirty = true, sending = false;
const values = () => Object.fromEntries(['prompt', 'second', 'editor'].map(id => {
  const el = document.getElementById(id);
  return [id, (el.value ?? el.textContent).slice(0, 2000)];
}));
const snapshot = () => ({
  run, mode, keydowns, duplicates, repeats, prevented, inputs,
  elapsedMs: Math.round(performance.now() - started), combinations, recent, firstKeydowns,
  focus: document.activeElement?.id, values: values(),
});
document.addEventListener('keydown', event => {
  const observedMs = performance.now() - started;
  const chord = [event.metaKey && 'Cmd', event.ctrlKey && 'Ctrl',
    event.altKey && 'Alt', event.shiftKey && 'Shift', event.code].filter(Boolean).join('+');
  const identity = `${event.timeStamp}:${chord}:${event.repeat}`;
  const duplicate = seen.has(identity);
  const previous = arrivals.get(identity);
  arrivals.set(identity, { first: previous?.first ?? observedMs, last: observedMs });
  if (arrivals.size > 1024) arrivals.delete(arrivals.keys().next().value);
  seen.add(identity);
  if (seen.size > 20000) seen.delete(seen.values().next().value);
  keydowns++;
  if (duplicate) duplicates++;
  if (event.repeat) repeats++;
  const bucket = combinations[chord] ??= { count: 0, duplicates: 0, repeats: 0 };
  bucket.count++;
  if (duplicate) bucket.duplicates++;
  if (event.repeat) bucket.repeats++;
  if (mode === 'E' && (event.metaKey || event.ctrlKey)) {
    event.preventDefault();
    prevented++;
  }
  const observation = { chord, timestamp: event.timeStamp, repeat: event.repeat,
    observedMs, sinceFirstMs: observedMs - (previous?.first ?? observedMs),
    sincePreviousMs: previous ? observedMs - previous.last : null,
    duplicate, prevented: event.defaultPrevented, target: event.target.id, trusted: event.isTrusted };
  recent.push(observation);
  if (firstKeydowns.length < 32) firstKeydowns.push(observation);
  if (recent.length > 12) recent.shift();
  dirty = true;
}, true);
for (const name of ['keyup', 'focusin', 'input', 'selectionchange']) {
  document.addEventListener(name, () => {
    if (name === 'input') inputs++;
    dirty = true;
  });
}
async function flush() {
  if (!dirty || sending) return;
  dirty = false;
  sending = true;
  document.getElementById('counter').textContent =
    `keydown ${keydowns} | duplicate ${duplicates} | repeat ${repeats} | prevented ${prevented}`;
  try {
    await fetch('/events', { method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(snapshot()) });
  } catch (_) { dirty = true; }
  finally { sending = false; }
}
setInterval(flush, 150);
document.getElementById('run').textContent = `Mode ${mode} / run ${run}`;
document.getElementById('prompt').focus();
