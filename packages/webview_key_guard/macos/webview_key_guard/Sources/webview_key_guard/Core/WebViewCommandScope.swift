import Cocoa

final class WebViewCommandScope {
  private struct Command {
    let source: NSView
    let event: NSEvent
  }
  private var commands: [Command] = []
  var depth: Int { commands.count }

  func perform<T>(from source: NSView, event: NSEvent,
                  _ body: () throws -> T) rethrows -> T {
    commands.append(Command(source: source, event: event))
    defer { commands.removeLast() }
    return try body()
  }

  func containsSource(for event: NSEvent, in view: NSView) -> Bool {
    commands.contains {
      $0.event === event && ($0.source === view || $0.source.isDescendant(of: view))
    }
  }

  private func isSource(_ view: NSView, for event: NSEvent) -> Bool {
    commands.contains { $0.event === event && $0.source === view }
  }

  // Only descend through ancestors of the source. Other branches retain their
  // own performKeyEquivalent implementations, including native Cancel buttons.
  func performOutsideSource(_ event: NSEvent, in view: NSView) -> Bool {
    if isSource(view, for: event) { return false }
    if !containsSource(for: event, in: view) {
      return view.performKeyEquivalent(with: event)
    }
    for child in view.subviews {
      if performOutsideSource(event, in: child) { return true }
    }
    return false
  }
}

final class WebViewCommandBoundary: NSView {
  private let scope: WebViewCommandScope
  private let configuration: WebViewKeyGuardConfiguration

  init(scope: WebViewCommandScope, configuration: WebViewKeyGuardConfiguration) {
    self.scope = scope
    self.configuration = configuration
    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) { fatalError("Use init(scope:configuration:)") }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if configuration.enabled && scope.containsSource(for: event, in: self) {
      return scope.performOutsideSource(event, in: self)
    }
    return super.performKeyEquivalent(with: event)
  }
}
