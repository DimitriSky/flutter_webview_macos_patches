import Cocoa
import FlutterMacOS
import WebKit
import webview_key_guard

final class LabFlutterViewController: WebViewKeyGuardFlutterViewController {
  override func keyDown(with event: NSEvent) {
    let lab = KeyboardExperiment.shared
    lab.recordTrace("flutter.keyDown.in", event, receiver: self)
    let webViewFocused = webViewHasFocus
    guard lab.recordFlutter(event, webViewFocused: webViewFocused) else { return }
    if lab.strategy.usesCurrentPackage {
      lab.recordTrace("flutter.keyDown.package", event)
      super.keyDown(with: event)
      return
    }
    if lab.strategy.routesWebViewOutsideFlutter && webViewFocused {
      // WebKit's synchronous resend must not enter Flutter's asynchronous queue.
      lab.didRoute()
      lab.recordTrace("flutter.keyDown.route", event, receiver: self)
      nextResponder?.keyDown(with: event)
      return
    }
    lab.recordTrace("flutter.keyDown.super", event)
    super.keyDown(with: event)
  }

  override func keyUp(with event: NSEvent) {
    let lab = KeyboardExperiment.shared
    lab.recordTrace("flutter.keyUp.in", event)
    if lab.strategy.routesKeyUpAndFlags && webViewHasFocus {
      lab.recordTrace("flutter.keyUp.route", event)
      nextResponder?.keyUp(with: event)
    } else {
      lab.recordTrace("flutter.keyUp.super", event)
      super.keyUp(with: event)
    }
  }

  override func flagsChanged(with event: NSEvent) {
    let lab = KeyboardExperiment.shared
    lab.recordTrace("flutter.flagsChanged.in", event)
    if lab.strategy.routesKeyUpAndFlags && webViewHasFocus {
      lab.recordTrace("flutter.flagsChanged.route", event)
      nextResponder?.flagsChanged(with: event)
    } else {
      lab.recordTrace("flutter.flagsChanged.super", event)
      super.flagsChanged(with: event)
    }
  }

  private var webViewHasFocus: Bool {
    var responder = view.window?.firstResponder
    while let current = responder {
      if current is WKWebView { return true }
      responder = current.nextResponder
    }
    return false
  }
}
