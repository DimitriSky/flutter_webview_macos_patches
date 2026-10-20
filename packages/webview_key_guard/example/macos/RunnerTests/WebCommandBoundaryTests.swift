import Cocoa
import XCTest
@testable import flutter_webview_repeated_keys

final class WebCommandBoundaryTests: XCTestCase {
  private final class EquivalentView: NSView {
    var calls = 0
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
      calls += 1
      return true
    }
  }

  private func key(_ code: UInt16 = 53, flags: NSEvent.ModifierFlags = .shift,
                   repeatKey: Bool = false) -> NSEvent {
    NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                    timestamp: 10, windowNumber: 0, context: nil,
                    characters: "a", charactersIgnoringModifiers: "a",
                    isARepeat: repeatKey, keyCode: code)!
  }

  func testSourceIsExcludedOnlyDuringItsOwnCommand() {
    let scope = WebCommandScope()
    let boundary = WebCommandBoundaryView(scope: scope)
    let source = EquivalentView()
    boundary.addSubview(source)
    let event = key()
    XCTAssertTrue(boundary.performKeyEquivalent(with: event))
    scope.perform(from: source, event: event, selector: #selector(NSResponder.cancelOperation(_:))) {
      XCTAssertFalse(boundary.performKeyEquivalent(with: event))
      XCTAssertEqual(source.calls, 1)
      XCTAssertEqual(scope.skippedEquivalents, 1)
    }
    XCTAssertTrue(boundary.performKeyEquivalent(with: event))
    XCTAssertEqual(source.calls, 2)
    XCTAssertEqual(scope.snapshot["activeDepth"] as? Int, 0)
  }

  func testIndependentKeysAndRepeatAreNotFilteredInsideCommand() {
    let scope = WebCommandScope()
    let boundary = WebCommandBoundaryView(scope: scope)
    let source = EquivalentView()
    boundary.addSubview(source)
    scope.perform(from: source, event: key(), selector: #selector(NSResponder.cancelOperation(_:))) {
      XCTAssertTrue(boundary.performKeyEquivalent(with: key()))
      XCTAssertTrue(boundary.performKeyEquivalent(with: key(repeatKey: true)))
      XCTAssertTrue(boundary.performKeyEquivalent(with: key(11, flags: .command)))
    }
    XCTAssertEqual(source.calls, 3)
    XCTAssertEqual(scope.skippedEquivalents, 0)
  }

  func testUnrelatedSubtreeAndWindowAreNotExcluded() {
    let scope = WebCommandScope()
    let source = EquivalentView()
    let other = EquivalentView()
    let boundary = WebCommandBoundaryView(scope: scope)
    boundary.addSubview(other)
    let otherWindowScope = WebCommandScope()
    let event = key()
    scope.perform(from: source, event: event, selector: #selector(NSResponder.cancelOperation(_:))) {
      XCTAssertTrue(boundary.performKeyEquivalent(with: event))
      XCTAssertFalse(otherWindowScope.excludes(event, in: source))
    }
  }

  func testNestedCommandsAndThrowRestoreContext() {
    enum Failure: Error { case expected }
    let scope = WebCommandScope()
    let source = NSView()
    let first = key()
    let second = key(11, flags: .command)
    XCTAssertThrowsError(try scope.perform(from: source, event: first, selector: #selector(NSResponder.cancelOperation(_:))) {
      scope.perform(from: source, event: second, selector: #selector(NSResponder.selectAll(_:))) {
        XCTAssertTrue(scope.excludes(first, in: source))
        XCTAssertTrue(scope.excludes(second, in: source))
        XCTAssertEqual(scope.snapshot["activeDepth"] as? Int, 2)
      }
      XCTAssertFalse(scope.excludes(second, in: source))
      throw Failure.expected
    })
    XCTAssertFalse(scope.excludes(first, in: source))
    XCTAssertEqual(scope.snapshot["activeDepth"] as? Int, 0)
    scope.reset()
    XCTAssertEqual(scope.commands, 0)
  }
}
