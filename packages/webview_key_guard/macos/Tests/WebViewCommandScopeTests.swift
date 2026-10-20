import Cocoa
import XCTest
@testable import WebViewKeyGuardCore

final class WebViewCommandScopeTests: XCTestCase {
  private final class Source: NSView {
    var calls = 0
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
      calls += 1
      return true
    }
  }

  private final class ActionTarget: NSObject {
    var calls = 0
    @objc func cancel(_ sender: Any?) { calls += 1 }
  }

  private func event(repeatKey: Bool = false) -> NSEvent {
    NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .shift,
                    timestamp: 10, windowNumber: 0, context: nil,
                    characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                    isARepeat: repeatKey, keyCode: 53)!
  }

  private func configuration() -> WebViewKeyGuardConfiguration {
    let name = "WebViewCommandScopeTests.\(UUID())"
    let defaults = UserDefaults(suiteName: name)!
    addTeardownBlock { defaults.removePersistentDomain(forName: name) }
    return WebViewKeyGuardConfiguration(defaults: defaults)
  }

  func testOnlyTheSourceOfTheActiveCommandIsSkipped() {
    let scope = WebViewCommandScope()
    let boundary = WebViewCommandBoundary(scope: scope, configuration: configuration())
    let source = Source()
    boundary.addSubview(source)
    let key = event()
    XCTAssertTrue(boundary.performKeyEquivalent(with: key))
    scope.perform(from: source, event: key) {
      XCTAssertFalse(boundary.performKeyEquivalent(with: key))
      XCTAssertEqual(source.calls, 1)
      XCTAssertTrue(boundary.performKeyEquivalent(with: event()))
      XCTAssertTrue(boundary.performKeyEquivalent(with: event(repeatKey: true)))
    }
    XCTAssertTrue(boundary.performKeyEquivalent(with: key))
    XCTAssertEqual(source.calls, 4)
    XCTAssertEqual(scope.depth, 0)
  }

  func testNativeCancelButtonInsideSameHostStillReceivesEquivalent() {
    _ = NSApplication.shared
    let scope = WebViewCommandScope()
    let boundary = WebViewCommandBoundary(scope: scope, configuration: configuration())
    let nested = NSView()
    let source = Source()
    let target = ActionTarget()
    let cancel = NSButton(title: "Cancel", target: target, action: #selector(ActionTarget.cancel(_:)))
    cancel.keyEquivalent = "\u{1b}"
    cancel.keyEquivalentModifierMask = .shift
    boundary.addSubview(nested)
    nested.addSubview(source)
    nested.addSubview(cancel)
    let key = event()
    scope.perform(from: source, event: key) {
      XCTAssertTrue(boundary.performKeyEquivalent(with: key))
    }
    XCTAssertEqual(source.calls, 0)
    XCTAssertEqual(target.calls, 1)
  }

  func testUnhandledBoundaryLeavesOutsideCancelTargetAvailable() {
    _ = NSApplication.shared
    let root = NSView()
    let scope = WebViewCommandScope()
    let boundary = WebViewCommandBoundary(scope: scope, configuration: configuration())
    let source = Source()
    let target = ActionTarget()
    let cancel = NSButton(title: "Cancel", target: target, action: #selector(ActionTarget.cancel(_:)))
    cancel.keyEquivalent = "\u{1b}"
    cancel.keyEquivalentModifierMask = .shift
    root.addSubview(boundary)
    root.addSubview(cancel)
    boundary.addSubview(source)
    let key = event()
    scope.perform(from: source, event: key) {
      XCTAssertTrue(root.performKeyEquivalent(with: key))
    }
    XCTAssertEqual(source.calls, 0)
    XCTAssertEqual(target.calls, 1)
  }

  func testOffRestoresNormalDispatchEvenInsideCommand() {
    let configuration = configuration()
    let scope = WebViewCommandScope()
    let boundary = WebViewCommandBoundary(scope: scope, configuration: configuration)
    let source = Source()
    boundary.addSubview(source)
    let key = event()
    scope.perform(from: source, event: key) {
      configuration.setEnabled(false)
      XCTAssertTrue(boundary.performKeyEquivalent(with: key))
      configuration.setEnabled(true)
      XCTAssertFalse(boundary.performKeyEquivalent(with: key))
    }
    XCTAssertEqual(source.calls, 1)
  }

  func testNestedCommandsThrowAndSeparateWindowsDoNotLeakScope() {
    enum Failure: Error { case expected }
    let scope = WebViewCommandScope()
    let otherWindowScope = WebViewCommandScope()
    let source = Source()
    let key = event()
    let second = event()
    XCTAssertThrowsError(try scope.perform(from: source, event: key) {
      XCTAssertFalse(otherWindowScope.containsSource(for: key, in: source))
      scope.perform(from: source, event: second) {
        XCTAssertEqual(scope.depth, 2)
        XCTAssertTrue(scope.containsSource(for: key, in: source))
        XCTAssertTrue(scope.containsSource(for: second, in: source))
      }
      XCTAssertFalse(scope.containsSource(for: second, in: source))
      throw Failure.expected
    })
    XCTAssertEqual(scope.depth, 0)
    XCTAssertFalse(scope.containsSource(for: key, in: source))
  }

  func testNestedSourcesOnlyExcludeTheMatchingEventSource() {
    let scope = WebViewCommandScope()
    let boundary = WebViewCommandBoundary(scope: scope, configuration: configuration())
    let first = Source(), second = Source()
    boundary.addSubview(first)
    boundary.addSubview(second)
    let a = event(), b = event()
    scope.perform(from: first, event: a) {
      scope.perform(from: second, event: b) {
        XCTAssertTrue(boundary.performKeyEquivalent(with: a))
        XCTAssertEqual(first.calls, 0)
        XCTAssertEqual(second.calls, 1)
        XCTAssertTrue(boundary.performKeyEquivalent(with: b))
        XCTAssertEqual(first.calls, 1)
        XCTAssertEqual(second.calls, 1)
      }
    }
    XCTAssertEqual(scope.depth, 0)
    XCTAssertTrue(boundary.performKeyEquivalent(with: a))
    XCTAssertEqual(first.calls, 2)
  }
}
