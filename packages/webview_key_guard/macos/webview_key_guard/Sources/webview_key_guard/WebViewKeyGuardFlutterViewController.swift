import Cocoa
import FlutterMacOS

open class WebViewKeyGuardFlutterViewController: FlutterViewController {
  public let keyGuardConfiguration = WebViewKeyGuardConfiguration.shared
  private let keyRouting = WebViewKeyRouting()

  open override func keyDown(with event: NSEvent) {
    let webViewFocused = WebViewKeyFocus.source(from: view.window?.firstResponder) != nil
    switch keyRouting.route(event, webViewFocused: webViewFocused,
                            configuration: keyGuardConfiguration) {
    case .flutter:
      super.keyDown(with: event)
    case .nextResponder:
      nextResponder?.keyDown(with: event)
    case .duplicate:
      break
    }
  }
}
