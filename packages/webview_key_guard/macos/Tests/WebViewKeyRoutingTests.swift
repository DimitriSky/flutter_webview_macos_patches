import Cocoa
import WebKit
import XCTest
@testable import WebViewKeyGuardCore

final class WebViewKeyRoutingTests: XCTestCase {
  private func configuration() -> WebViewKeyGuardConfiguration {
    let name = "WebViewKeyRoutingTests.\(UUID())"
    let defaults = UserDefaults(suiteName: name)!
    addTeardownBlock { defaults.removePersistentDomain(forName: name) }
    return WebViewKeyGuardConfiguration(defaults: defaults)
  }

  private func key(_ code: UInt16 = 36, mask: Int = 1, repeatKey: Bool = false,
                   type: NSEvent.EventType = .keyDown) -> NSEvent {
    let flags: [NSEvent.ModifierFlags] = [.command, .control, .option, .shift]
    var modifiers: NSEvent.ModifierFlags = []
    for (bit, flag) in flags.enumerated() where mask & (1 << bit) != 0 { modifiers.insert(flag) }
    return NSEvent.keyEvent(with: type, location: .zero, modifierFlags: modifiers,
                           timestamp: 10, windowNumber: 0, context: nil,
                           characters: "a", charactersIgnoringModifiers: "a",
                           isARepeat: repeatKey, keyCode: code)!
  }

  func testAllKeyCodesAndModifierSetsRouteWithoutKeySpecificRules() {
    let configuration = configuration()
    let routing = WebViewKeyRouting()
    for code in UInt16(0)...127 {
      for mask in 0..<16 {
        let event = key(code, mask: mask)
        XCTAssertEqual(routing.route(event, webViewFocused: true, configuration: configuration), .nextResponder)
        XCTAssertEqual(routing.route(event, webViewFocused: true, configuration: configuration), .duplicate)
        XCTAssertEqual(routing.route(key(code, mask: mask), webViewFocused: true, configuration: configuration), .nextResponder)
        XCTAssertEqual(routing.route(key(code, mask: mask, repeatKey: true), webViewFocused: true, configuration: configuration), .nextResponder)
        XCTAssertEqual(routing.route(event, webViewFocused: false, configuration: configuration), .flutter)
      }
    }
  }

  func testOffBypassesRoutingAndGuardAndReenableStartsFresh() {
    let configuration = configuration()
    let routing = WebViewKeyRouting()
    let event = key()
    XCTAssertEqual(routing.route(event, webViewFocused: true, configuration: configuration), .nextResponder)
    configuration.setEnabled(false)
    for _ in 0..<3 {
      XCTAssertEqual(routing.route(event, webViewFocused: true, configuration: configuration), .flutter)
    }
    configuration.setEnabled(true)
    XCTAssertEqual(routing.route(event, webViewFocused: true, configuration: configuration), .nextResponder)
    XCTAssertEqual(routing.route(event, webViewFocused: true, configuration: configuration), .duplicate)
  }

  func testKeyUpAndUnfocusedInputAreNotFiltered() {
    let configuration = configuration()
    let routing = WebViewKeyRouting()
    XCTAssertEqual(routing.route(key(type: .keyUp), webViewFocused: true, configuration: configuration), .flutter)
    let event = key()
    XCTAssertEqual(routing.route(event, webViewFocused: false, configuration: configuration), .flutter)
    XCTAssertEqual(routing.route(event, webViewFocused: true, configuration: configuration), .nextResponder)
  }

  func testPreferenceDefaultsOnAndSurvivesRecreation() {
    let name = "WebViewKeyGuardPersistenceTests.\(UUID())"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    let configuration = WebViewKeyGuardConfiguration(defaults: defaults)
    XCTAssertTrue(configuration.enabled)
    configuration.setEnabled(false)
    XCTAssertFalse(WebViewKeyGuardConfiguration(defaults: defaults).enabled)
    configuration.setEnabled(true)
    XCTAssertTrue(WebViewKeyGuardConfiguration(defaults: defaults).enabled)
  }

  func testSeparateControllersDoNotShareDuplicateHistory() {
    let configuration = configuration()
    let first = WebViewKeyRouting(), second = WebViewKeyRouting()
    let event = key()
    XCTAssertEqual(first.route(event, webViewFocused: true, configuration: configuration), .nextResponder)
    XCTAssertEqual(second.route(event, webViewFocused: true, configuration: configuration), .nextResponder)
    XCTAssertEqual(first.route(event, webViewFocused: true, configuration: configuration), .duplicate)
    XCTAssertEqual(second.route(event, webViewFocused: true, configuration: configuration), .duplicate)
  }

  func testDuplicateHistoryDoesNotKeepEventsAlive() {
    let configuration = configuration(), routing = WebViewKeyRouting()
    weak var released: NSEvent?
    autoreleasepool {
      let event = key()
      released = event
      XCTAssertEqual(routing.route(event, webViewFocused: true, configuration: configuration), .nextResponder)
      XCTAssertEqual(routing.route(event, webViewFocused: true, configuration: configuration), .duplicate)
    }
    XCTAssertNil(released)
    XCTAssertEqual(routing.route(key(), webViewFocused: true, configuration: configuration), .nextResponder)
  }

  func testFocusFindsWebViewThroughResponderChainAndBoundsCycles() {
    _ = NSApplication.shared
    let webView = WKWebView(frame: .zero)
    let field = NSResponder(), intermediate = NSResponder()
    field.nextResponder = intermediate
    intermediate.nextResponder = webView
    XCTAssertTrue(WebViewKeyFocus.source(from: field) === webView)
    XCTAssertTrue(WebViewKeyFocus.source(from: webView) === webView)
    intermediate.nextResponder = field
    defer { field.nextResponder = nil; intermediate.nextResponder = nil }
    XCTAssertNil(WebViewKeyFocus.source(from: field))
    XCTAssertNil(WebViewKeyFocus.source(from: nil))
  }
}
