import Cocoa

/// Use together with WebViewKeyGuardFlutterViewController and keyGuardHost(for:).
open class WebViewKeyGuardWindow: NSWindow {
  public let keyGuardConfiguration = WebViewKeyGuardConfiguration.shared
  private let commandScope = WebViewCommandScope()

  public func keyGuardHost(for content: NSViewController) -> NSViewController {
    WebViewKeyGuardHost(content: content, scope: commandScope,
                        configuration: keyGuardConfiguration)
  }

  open override func doCommand(by selector: Selector) {
    guard keyGuardConfiguration.enabled,
          let event = NSApp.currentEvent, event.type == .keyDown,
          let source = WebViewKeyFocus.source(from: firstResponder) else {
      super.doCommand(by: selector)
      return
    }
    commandScope.perform(from: source, event: event) {
      super.doCommand(by: selector)
    }
  }
}

private final class WebViewKeyGuardHost: NSViewController {
  init(content: NSViewController, scope: WebViewCommandScope,
       configuration: WebViewKeyGuardConfiguration) {
    super.init(nibName: nil, bundle: nil)
    view = WebViewCommandBoundary(scope: scope, configuration: configuration)
    view.frame = content.view.frame
    addChild(content)
    content.view.frame = view.bounds
    content.view.autoresizingMask = [.width, .height]
    view.addSubview(content.view)
  }

  required init?(coder: NSCoder) { fatalError("Use init(content:scope:configuration:)") }
}
