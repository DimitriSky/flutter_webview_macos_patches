## 0.1.0

- Skip the Flutter engine re-adding an already attached platform view container on each frame,
  so WebKit hover stays under the mouse.
- `WebViewHoverGuard.status()` and `setEnabled()` for diagnostics and A/B checks.
