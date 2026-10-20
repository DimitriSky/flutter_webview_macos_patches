// Injected into the real pages by proxy.py. Logs pointer, hover and focus without changing the page.
(() => {
  const t0 = performance.now();
  const iid = Math.random().toString(36).slice(2, 7);
  const buf = [];
  const page = location.pathname;
  const id = el => {
    if (!el || !el.nodeName) return String(el);
    if (el.id) return '#' + el.id;
    const text = (el.textContent || '').trim().slice(0, 18);
    const cls = typeof el.className === 'string' && el.className ? '.' + el.className.trim().split(/\s+/).join('.') : '';
    return el.nodeName.toLowerCase() + cls + (el.nodeName === 'BUTTON' && text ? `"${text}"` : '');
  };
  const log = o => { o.t = Math.round(performance.now() - t0); o.page = page; o.iid = iid; o.now = Date.now() / 1000; buf.push(o); };
  setInterval(() => {
    if (!buf.length) return;
    fetch('/__log', { method: 'POST', body: JSON.stringify(buf.splice(0)), headers: { 'content-type': 'application/json' } }).catch(() => {});
  }, 250);
  log({ ev: 'load', ua: navigator.userAgent, w: innerWidth, h: innerHeight });

  let last = null;
  for (const type of ['pointermove']) {
    document.addEventListener(type, e => {
      last = { x: e.clientX, y: e.clientY, t: performance.now() };
      log({ ev: type, x: Math.round(e.clientX), y: Math.round(e.clientY), sx: e.screenX, sy: e.screenY, tgt: id(e.target), b: e.buttons, trusted: e.isTrusted });
    }, true);
  }
  for (const type of ['mouseover', 'mouseout', 'pointerdown', 'pointerup', 'contextmenu']) {
    document.addEventListener(type, e => log({ ev: type, x: Math.round(e.clientX), y: Math.round(e.clientY), tgt: id(e.target), rel: id(e.relatedTarget), btn: e.button, trusted: e.isTrusted }), true);
  }
  for (const type of ['focusin', 'focusout']) {
    document.addEventListener(type, e => log({ ev: type, tgt: id(e.target), fv: e.target.matches?.(':focus-visible') }), true);
  }
  window.addEventListener('focus', () => log({ ev: 'window-focus' }));
  window.addEventListener('blur', () => log({ ev: 'window-blur' }));
  document.addEventListener('visibilitychange', () => log({ ev: 'visibility', s: document.visibilityState }));
  window.addEventListener('resize', () => log({ ev: 'resize', w: innerWidth, h: innerHeight }));
  document.addEventListener('scroll', e => log({ ev: 'scroll', tgt: id(e.target) }), true);

  // Every frame: the deepest :hover element vs the element really under the last pointer position.
  // A mismatch while the mouse is still means the highlight does not follow the mouse.
  let prev = '';
  const tick = () => {
    const hov = [...document.querySelectorAll(':hover')].pop();
    const under = last ? document.elementFromPoint(last.x, last.y) : null;
    const a = document.activeElement;
    const s = JSON.stringify({ hov: id(hov), under: id(under), active: id(a), fv: !!a?.matches(':focus-visible'), hasFocus: document.hasFocus() });
    if (s !== prev) {
      prev = s;
      const o = JSON.parse(s);
      o.mismatch = !!(hov && under && hov !== under && !hov.contains(under) && !under.contains(hov));
      o.sinceMove = last ? Math.round(performance.now() - last.t) : null;
      log({ ev: 'state', ...o });
    }
    requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);

  // Rects of menu triggers and menu items, so a test driver can aim the real mouse.
  const rects = () => {
    const pick = sel => [...document.querySelectorAll(sel)].slice(0, 6).map(el => { const r = el.getBoundingClientRect(); return [id(el), Math.round(r.left), Math.round(r.top), Math.round(r.right), Math.round(r.bottom)]; });
    log({ ev: 'rects', more: pick('.more'), menu: pick('.menu button'), tile: pick('.tile[data-name]'), ctx: pick('.ctx:not([hidden]) button'), tabs: pick('.tab') });
  };
  setTimeout(rects, 500);
  let pending = 0;
  new MutationObserver(() => { clearTimeout(pending); pending = setTimeout(rects, 200); }).observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['hidden'] });
})();
