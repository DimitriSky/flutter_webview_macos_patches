import FlutterMacOS

public final class WebViewKeyGuardPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "webview_key_guard", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(WebViewKeyGuardPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let configuration = WebViewKeyGuardConfiguration.shared
    switch call.method {
    case "getEnabled":
      result(configuration.enabled)
    case "setEnabled":
      guard let arguments = call.arguments as? [String: Any],
            let enabled = arguments["enabled"] as? Bool else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected enabled boolean.", details: nil))
        return
      }
      configuration.setEnabled(enabled)
      result(configuration.enabled)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
