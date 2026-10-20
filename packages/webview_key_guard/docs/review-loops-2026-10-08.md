# Isolated package review · 2026-10-08

Scope: `webview_key_guard` Dart API, native routing/command boundary, and its
owned `example`. Consumer applications and the lab's historical strategies
are outside this audit. Maximum five rounds; each completed round is committed
with a `loop` prefix. Historical evidence is not counted as a new pass.

## Round 1 — native policy and API

No important production defect was confirmed; no runtime code change was needed.

Reviewed event-object identity, weak ownership, per-controller isolation,
configuration revision invalidation, responder-chain focus detection, command
scope nesting/error cleanup, and preservation of neighboring native controls.
The existing 128 key codes × 16 modifier combinations test separates repeated
delivery of one native object from fresh objects and legitimate auto-repeat.

Added four native regressions:

- Independent controllers have independent event histories.
- Duplicate history does not retain completed native events.
- Focus discovery finds a WebView through intermediate responders and terminates
  safely on cycles/missing responders.
- Nested commands with different sources exclude only the matching event's
  source, preserving other subtrees and cleanup afterward.

Added Dart regressions for native error propagation and rejecting non-boolean
`setEnabled` acknowledgments. Failures must not fabricate a protection state.

Baseline: 9 native and 3 package Dart tests passed. Expanded native suite:
13 tests passed. Expanded package suite: 5 Dart tests passed on Flutter 3.47.5;
targeted package analyzer is clean. Example: 7 Dart and 4 Node tests passed,
analyzer clean.
Baseline package Dart checks used Flutter 3.44.6; example checks use its
existing Flutter 3.47.5 SDK. Example dependency versions are retained.

Secondary verification/API ideas are recorded in
[future-improvements.md](future-improvements.md). Native policy tests are not
physical-keyboard qualification. The next round checks the actual isolated
runner with WebKit observation exchanges disabled.

## Round 2 — actual isolated macOS runner

No additional important production defect was found. Runtime package sources
were not changed; added verification lives only in the owned example.

Added a Flutter native integration fixture and a repeatable count-only evidence
runner. The fixture uses the actual guarded window, host/controller and plugin,
an owned inline HTML page, and synthetic NSEvents dispatched through the app's
own AppKit queue. This supplies the real `NSApp.currentEvent` context needed by
the native command boundary, without injecting system-wide input.

`KEY_LAB_WEBKIT_OBSERVATION=off` disables WKWebView method exchanges, and
`KEY_LAB_TRACE_STACKS=off` disables stack sampling. Historical B3 and its routing
guards do not participate. A run fails if the emergency breaker fires; this
cannot be counted as successful package protection.

The native fixture passed twice on Flutter 3.47.5 / Dart 3.13.4:

- Shift+Escape, Cmd+B and Cmd+Enter each produced exactly one DOM keyDown in
  input, textarea and contenteditable targets (nine shortcut observations).
- One initial letter plus four distinct native repeat events arrived intact,
  followed by one keyUp. This is generated repeat-flag coverage, not a human
  holding a hardware key.
- Select All, replacement typing, Undo and Redo behaved correctly without using
  the system clipboard.
- Disabling protection passed an ordinary letter; re-enabling passed a fresh
  letter. Flutter text input worked, received no page keyDown, and a fresh
  WebView keyDown arrived after focus returned.
- Final page: 21 keyDowns, 8 keyUps, 4 repeats, zero duplicate observations and
  zero prevented events. Native lab suppression/routing and historical command
  counters remained zero; no emergency restart was required.

Count-only evidence: [package isolation](../example/evidence/package-isolation-review-20261008.json).
The example adds the SDK integration-test dev dependency and its lockfile
entries; existing runtime dependencies and SDK are retained.

Scope stayed inside the package and its example. No consumer code/pins were
changed, no historical strategies were redesigned, and no full-application
audit was performed. Physical keyboard qualification and host-specific
extensions remain in [future improvements](future-improvements.md).

Final checks: 13 standalone AppKit tests, 5 package Dart tests, 7 example Dart
tests, 4 Node tests, and the native integration fixture all pass. Package
lib/test and example analyzers are clean. The ordinary macOS Debug build
succeeds and restores `lib/main.dart` after the fixture. No new physical
keyboard run or full live shortcut matrix is claimed.

Stopped after two rounds: no confirmed important production defect remains in
the reviewed scenarios. Both rounds add regression coverage and documentation;
the guard's shipped algorithm, APIs, and native bootstrap contract are unchanged.
