import Cocoa
import WebKit
import webview_key_guard

// A command is already the result of interpreting a key. Do not reinterpret
// that same key in its source subtree during the command's native fallback.
final class WebCommandScope {
  private struct Context {
    let source: NSView
    let event: NSEvent
  }
  private var contexts: [Context] = []
  private(set) var commands = 0
  private(set) var skippedEquivalents = 0
  private(set) var selectors: [String: Int] = [:]

  func perform<T>(from source: NSView, event: NSEvent, selector: Selector,
                  _ body: () throws -> T) rethrows -> T {
    contexts.append(Context(source: source, event: event))
    commands += 1
    selectors[NSStringFromSelector(selector), default: 0] += 1
    defer { contexts.removeLast() }
    return try body()
  }

  func excludes(_ event: NSEvent, in subtree: NSView) -> Bool {
    contexts.contains {
      $0.event === event && ($0.source === subtree || $0.source.isDescendant(of: subtree))
    }
  }

  func didSkip() { skippedEquivalents += 1 }

  func reset() {
    precondition(contexts.isEmpty)
    commands = 0
    skippedEquivalents = 0
    selectors = [:]
  }

  var snapshot: [String: Any] {
    ["commands": commands, "skippedEquivalents": skippedEquivalents,
     "activeDepth": contexts.count, "selectors": selectors]
  }
}

final class WebCommandBoundaryView: NSView {
  let scope: WebCommandScope

  init(scope: WebCommandScope) {
    self.scope = scope
    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) { fatalError("Use init(scope:)") }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if scope.excludes(event, in: self) {
      scope.didSkip()
      KeyboardExperiment.shared.recordTrace("command.equivalent.skip", event, receiver: self)
      // Not handled here: keep AppKit's remaining command targets available.
      return false
    }
    return super.performKeyEquivalent(with: event)
  }
}

final class WebCommandHostController: NSViewController {
  init(content: NSViewController, scope: WebCommandScope) {
    super.init(nibName: nil, bundle: nil)
    view = WebCommandBoundaryView(scope: scope)
    addChild(content)
    content.view.frame = view.bounds
    content.view.autoresizingMask = [.width, .height]
    view.addSubview(content.view)
  }

  required init?(coder: NSCoder) { fatalError("Use init(content:scope:)") }
}

class WebCommandWindow: WebViewKeyGuardWindow {
  let webCommandScope = WebCommandScope()

  override func doCommand(by selector: Selector) {
    let lab = KeyboardExperiment.shared
    guard lab.strategy.isolatesNativeCommandFallback,
          let event = NSApp.currentEvent, event.type == .keyDown,
          let source = focusedWebView else {
      super.doCommand(by: selector)
      return
    }
    lab.recordTrace("window.command.in", event, detail: NSStringFromSelector(selector), receiver: self)
    webCommandScope.perform(from: source, event: event, selector: selector) {
      super.doCommand(by: selector)
    }
    lab.recordTrace("window.command.out", event, detail: NSStringFromSelector(selector))
  }

  private var focusedWebView: WKWebView? {
    var responder = firstResponder
    var visited = Set<ObjectIdentifier>()
    while let current = responder, visited.insert(ObjectIdentifier(current)).inserted {
      if let webView = current as? WKWebView { return webView }
      responder = current.nextResponder
    }
    return nil
  }
}
