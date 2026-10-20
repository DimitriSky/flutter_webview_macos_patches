import Cocoa
import FlutterMacOS

/// Registering the plugin is enough: it patches the engine at registration.
public final class WebViewHoverGuardPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    ReinsertGuard.shared.installForFlutter()
    let channel = FlutterMethodChannel(name: "webview_hover_guard", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(WebViewHoverGuardPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let guardian = ReinsertGuard.shared
    switch call.method {
    case "status":
      result(guardian.status)
    case "setEnabled":
      guard let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected enabled boolean.", details: nil))
        return
      }
      guardian.enabled = enabled
      result(guardian.status)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
