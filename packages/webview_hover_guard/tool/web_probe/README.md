# Web probe

Checks hover on a real page inside a real app.

- `probe.js` — logs pointer, `mouseover`, focus and, every frame, the hovered element versus
  the element really under the last pointer position (`mismatch: true` = the bug).
  Also logs rects of menu items so a driver can aim the mouse.
- `proxy.py` — serves the page with `probe.js` injected; see its docstring.
- `mouse.swift` — real mouse driver: `swiftc -O mouse.swift -o /tmp/mouse`, then
  `/tmp/mouse move X Y`, `click X Y`, `rclick X Y`, `pos`, `check`
  (global coordinates; needs Accessibility permission).

Typical check in a debug app: open the page, rest the mouse on a menu item, force a frame
through the VM service (`ext.flutter.reassemble`) and look for `mismatch` in the log.
Toggle the fix with `WebViewHoverGuard().setEnabled(false/true)` to compare.
