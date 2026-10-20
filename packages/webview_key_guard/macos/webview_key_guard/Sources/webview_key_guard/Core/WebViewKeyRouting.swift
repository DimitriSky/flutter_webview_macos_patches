import Cocoa
import WebKit

enum WebViewKeyRoute {
  case flutter
  case nextResponder
  case duplicate
}

final class WebViewKeyRouting {
  private let seen = NSHashTable<NSEvent>(options: [.weakMemory, .objectPointerPersonality])
  private var revision = -1

  func route(_ event: NSEvent, webViewFocused: Bool,
             configuration: WebViewKeyGuardConfiguration) -> WebViewKeyRoute {
    if revision != configuration.revision {
      seen.removeAllObjects()
      revision = configuration.revision
    }
    guard configuration.enabled, webViewFocused, event.type == .keyDown else { return .flutter }
    guard !seen.contains(event) else { return .duplicate }
    seen.add(event)
    return .nextResponder
  }
}

enum WebViewKeyFocus {
  static func source(from responder: NSResponder?) -> WKWebView? {
    var current = responder
    var visited = Set<ObjectIdentifier>()
    while let candidate = current, visited.insert(ObjectIdentifier(candidate)).inserted {
      if let webView = candidate as? WKWebView { return webView }
      current = candidate.nextResponder
    }
    return nil
  }
}
