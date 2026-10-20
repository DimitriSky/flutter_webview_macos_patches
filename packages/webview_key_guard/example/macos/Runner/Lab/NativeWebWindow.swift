import Cocoa
import WebKit

final class NativeWebWindow {
  private var window: NSWindow?

  func open(url: URL) {
    if let window = window {
      window.makeKeyAndOrderFront(nil)
      return
    }
    let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 850, height: 650))
    let window = NSWindow(contentRect: webView.frame,
                          styleMask: [.titled, .closable, .resizable, .miniaturizable],
                          backing: .buffered, defer: false)
    window.title = "WebView Key Lab - D Native"
    window.isReleasedWhenClosed = false
    window.contentView = webView
    window.center()
    window.makeKeyAndOrderFront(nil)
    webView.load(URLRequest(url: url))
    self.window = window
  }

  func close() {
    (window?.contentView as? WKWebView)?.stopLoading()
    window?.close()
    window = nil
  }
}
