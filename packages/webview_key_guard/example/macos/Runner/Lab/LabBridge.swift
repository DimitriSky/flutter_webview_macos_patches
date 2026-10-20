import Cocoa
import FlutterMacOS
import WebKit

final class LabBridge {
  private let nativeWindow = NativeWebWindow()
  private let channel: FlutterMethodChannel

  init(controller: FlutterViewController) {
    channel = FlutterMethodChannel(name: "dev.dmilab.keylab", binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      let lab = KeyboardExperiment.shared
      switch call.method {
      case "configure":
        guard let args = call.arguments as? [String: String],
              let mode = args["mode"], let run = args["run"],
              lab.configure(id: mode, run: run) else {
          result(FlutterError(code: "restart_required", message: "Clean restart required after loop", details: nil))
          return
        }
        self.nativeWindow.close()
        (controller.view.window as? WebCommandWindow)?.webCommandScope.reset()
        result(nil)
      case "openNative":
        guard let value = call.arguments as? String, let url = URL(string: value),
              url.host == "127.0.0.1", url.scheme == "http" else {
          result(FlutterError(code: "invalid_url", message: "Expected local diagnostic URL", details: nil))
          return
        }
        self.nativeWindow.open(url: url)
        result(nil)
      case "snapshot":
        var snapshot = lab.snapshot
        snapshot["commandRouting"] = (controller.view.window as? WebCommandWindow)?.webCommandScope.snapshot
        result(snapshot)
      case "loadResults":
        result(UserDefaults.standard.string(forKey: "keyLabResults") ?? "{}")
      case "saveResults":
        if let value = call.arguments as? String {
          UserDefaults.standard.set(value, forKey: "keyLabResults")
        }
        result(nil)
      case "stop":
        lab.stop()
        self.nativeWindow.close()
        result(nil)
      case "reviewFocus":
        guard let window = controller.view.window, let target = call.arguments as? String else {
          result(FlutterError(code: "NO_WINDOW", message: "Missing review target window.", details: nil)); return
        }
        let responder: NSResponder? = target == "web" ? self.webView(in: controller.view) : controller.view
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        result(responder.map { window.makeFirstResponder($0) } ?? false)
      case "reviewKey":
        guard let window = controller.view.window, let args = call.arguments as? [String: Any],
              let code = args["code"] as? Int, (0...127).contains(code),
              let text = args["text"] as? String, text.count <= 4,
              let mask = args["mask"] as? Int, (0...15).contains(mask) else {
          result(FlutterError(code: "KEY_ARGS", message: "Invalid owned test key.", details: nil)); return
        }
        var flags: NSEvent.ModifierFlags = []
        for (bit, flag) in [NSEvent.ModifierFlags.command, .control, .option, .shift].enumerated()
          where mask & (1 << bit) != 0 { flags.insert(flag) }
        let type: NSEvent.EventType = args["up"] as? Bool == true ? .keyUp : .keyDown
        guard let event = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags,
          timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
          context: nil, characters: text, charactersIgnoringModifiers: text,
          isARepeat: type == .keyDown && args["repeat"] as? Bool == true, keyCode: UInt16(code)) else {
          result(FlutterError(code: "KEY_EVENT", message: "Cannot construct native test event.", details: nil)); return
        }
        // AppKit dequeues this event in the owned window, setting currentEvent
        // for the package's actual native command boundary. No OS injection.
        NSApp.postEvent(event, atStart: false)
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func webView(in view: NSView) -> WKWebView? {
    if let web = view as? WKWebView { return web }
    for child in view.subviews {
      if let web = webView(in: child) { return web }
    }
    return nil
  }

}
