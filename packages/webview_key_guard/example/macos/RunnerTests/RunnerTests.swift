import Cocoa
import FlutterMacOS
import XCTest
import webview_key_guard
@testable import flutter_webview_repeated_keys

class RunnerTests: XCTestCase {

  private func experiment() -> KeyboardExperiment {
    let name = "KeyLabPackageTests.\(UUID())"
    let defaults = UserDefaults(suiteName: name)!
    addTeardownBlock { defaults.removePersistentDomain(forName: name) }
    return KeyboardExperiment(packageConfiguration: WebViewKeyGuardConfiguration(defaults: defaults))
  }

  private func event(_ code: UInt16 = 36, mask: Int = 1,
                     timestamp: TimeInterval = 10, repeatKey: Bool = false) -> NSEvent {
    var flags: NSEvent.ModifierFlags = []
    if mask & 1 != 0 { flags.insert(.command) }
    if mask & 2 != 0 { flags.insert(.control) }
    if mask & 4 != 0 { flags.insert(.option) }
    if mask & 8 != 0 { flags.insert(.shift) }
    return NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                           timestamp: timestamp, windowNumber: 0, context: nil,
                           characters: "a", charactersIgnoringModifiers: "a",
                           isARepeat: repeatKey, keyCode: code)!
  }

  func testAllNativeKeyCodesAndModifierSets() {
    for code in UInt16(0)...127 {
      for mask in 0..<16 {
        let key = event(code, mask: mask)
        for id in ["P", "0", "A", "B", "B1", "B2", "B3", "C", "C2", "D", "E"] {
          let strategy = makeKeyStrategy(id)!
          XCTAssertEqual(strategy.usesCurrentPackage, id == "P")
          XCTAssertFalse(strategy.consumeBeforeWebKit(key, alreadySeen: false), "\(id) \(code) \(mask)")
          XCTAssertEqual(strategy.consumeBeforeWebKit(key, alreadySeen: true), id == "C" || id == "C2")
          XCTAssertEqual(strategy.consumeAfterWebKit(key), id == "A" && mask == 1 && [36, 76].contains(code))
          XCTAssertEqual(strategy.routesWebViewOutsideFlutter, ["B", "B1", "B2", "B3"].contains(id))
          XCTAssertEqual(strategy.routesKeyUpAndFlags, id == "B")
          XCTAssertEqual(strategy.guardsEveryStageIdentity, id == "C2")
          XCTAssertEqual(strategy.guardsFlutterIdentity, id == "B2" || id == "B3")
          XCTAssertEqual(strategy.isolatesNativeCommandFallback, id == "B3")
        }
      }
    }
  }

  func testIdentityIsNotTimeBasedDebouncing() {
    let ledger = EventLedger()
    let first = event()
    XCTAssertFalse(ledger.record(first))
    XCTAssertTrue(ledger.record(first))
    XCTAssertFalse(ledger.record(event(timestamp: 10.000001)))
    XCTAssertFalse(ledger.record(event(timestamp: 10.000002, repeatKey: true)))
    XCTAssertFalse(ledger.record(event(timestamp: 10.000003, repeatKey: true)))
    XCTAssertEqual(ledger.duplicateObjects, 1)
  }

  func testEmergencyBreakerIsAnAbortedRun() {
    let lab = experiment()
    XCTAssertTrue(lab.configure(id: "0", run: "baseline"))
    let key = event(11)
    for _ in 0..<255 { XCTAssertFalse(lab.beforeWebKit(key)) }
    XCTAssertTrue(lab.beforeWebKit(key))
    XCTAssertTrue(lab.restartRequired)
    XCTAssertFalse(lab.configure(id: "B", run: "must-not-reuse-poisoned-run"))
  }

  func testIdentityGuardAndFreshRuns() {
    let lab = experiment()
    XCTAssertTrue(lab.configure(id: "C", run: "one"))
    let key = event(11)
    XCTAssertFalse(lab.beforeWebKit(key))
    XCTAssertTrue(lab.beforeWebKit(key))
    XCTAssertEqual(lab.suppressed, 1)
    XCTAssertFalse(lab.restartRequired)
    XCTAssertTrue(lab.configure(id: "C", run: "two"))
    XCTAssertFalse(lab.beforeWebKit(key))
    XCTAssertEqual(lab.suppressed, 0)
  }

  func testFullIdentityOnlyDropsSameObjectAtEachStage() {
    let lab = experiment()
    XCTAssertTrue(lab.configure(id: "C2", run: "first"))
    let first = event(53, mask: 4)
    XCTAssertFalse(lab.beforeWebKitDown(first))
    XCTAssertTrue(lab.beforeWebKitDown(first))
    XCTAssertTrue(lab.recordFlutter(first, webViewFocused: true))
    XCTAssertFalse(lab.recordFlutter(first, webViewFocused: true))
    XCTAssertTrue(lab.recordFlutter(event(53, mask: 4, timestamp: 10.000001), webViewFocused: true))
    XCTAssertTrue(lab.recordFlutter(event(53, mask: 4, timestamp: 10.000002, repeatKey: true), webViewFocused: true))
    XCTAssertEqual(lab.suppressed, 2)
  }

  func testGuardedRoutingDropsOnlyRepeatedFlutterEntryWhenWebViewFocused() {
    let lab = experiment()
    XCTAssertTrue(lab.configure(id: "B2", run: "first"))
    let key = event(11, mask: 1)
    XCTAssertTrue(lab.recordFlutter(key, webViewFocused: true))
    XCTAssertFalse(lab.recordFlutter(key, webViewFocused: true))
    XCTAssertTrue(lab.recordFlutter(key, webViewFocused: false))
    XCTAssertFalse(lab.beforeWebKit(key))
    XCTAssertFalse(lab.beforeWebKit(key))
    XCTAssertFalse(lab.beforeWebKitDown(key))
    XCTAssertFalse(lab.beforeWebKitDown(key))
    XCTAssertEqual(lab.suppressed, 1)
  }

  func testTracePreservesStartOfFloodAndMeasuresArrivalSeparately() {
    let trace = NativeKeyTrace(captureStacks: false)
    let key = event(53, mask: 8)
    for _ in 0..<800 { trace.record("wk.equivalent.in", key, depth: 1) }
    let snapshot = trace.snapshot
    let recent = snapshot["trace"] as! [[String: Any]]
    let first = snapshot["firstTrace"] as! [[String: Any]]
    let starts = snapshot["eventStarts"] as! [[[String: Any]]]
    XCTAssertEqual(recent.count, 512)
    XCTAssertEqual(first.count, 96)
    XCTAssertEqual(starts.first?.count, 32)
    XCTAssertEqual(first.first?["sequence"] as? Int, 1)
    XCTAssertEqual(recent.first?["sequence"] as? Int, 289)
    XCTAssertEqual(first.first?["timestamp"] as? Double, 10)
    XCTAssertGreaterThan(recent.last!["observedMs"] as! Double, first.first!["observedMs"] as! Double)
    XCTAssertTrue((snapshot["stackSamples"] as! [[String: Any]]).isEmpty)
  }

  func testDiagnosticsAcceptModifierFlagEventsWithoutReadingKeyRepeat() {
    let trace = NativeKeyTrace(captureStacks: false)
    let modifier = NSEvent.keyEvent(with: .flagsChanged, location: .zero,
                                    modifierFlags: [.shift], timestamp: 11,
                                    windowNumber: 0, context: nil,
                                    characters: "", charactersIgnoringModifiers: "",
                                    isARepeat: false, keyCode: 56)!

    trace.record("window.sendEvent", modifier)

    let rows = trace.snapshot["trace"] as! [[String: Any]]
    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(rows[0]["type"] as? Int, Int(NSEvent.EventType.flagsChanged.rawValue))
    XCTAssertEqual(rows[0]["repeat"] as? Bool, false)

    let ledger = EventLedger()
    XCTAssertFalse(ledger.record(modifier))
    let recent = ledger.snapshot["recent"] as! [[String: Any]]
    XCTAssertEqual(recent.count, 1)
    XCTAssertEqual(recent[0]["repeat"] as? Bool, false)
  }

  func testPackageIsEnabledOnlyForPAndInvalidSelectionDoesNotChangeIt() {
    let lab = experiment()
    for id in ["P", "B3", "0", "P", "D", "C2", "P"] {
      XCTAssertTrue(lab.configure(id: id, run: "run-\(id)"))
      XCTAssertEqual(lab.snapshot["packageEnabled"] as? Bool, id == "P")
      XCTAssertEqual(lab.snapshot["implementation"] as? String, id == "P" ? "webview_key_guard" : "lab")
    }
    XCTAssertFalse(lab.configure(id: "unknown", run: "invalid"))
    XCTAssertEqual(lab.snapshot["packageEnabled"] as? Bool, true)
    let key = event(53, mask: 8)
    for _ in 0..<3 {
      XCTAssertFalse(lab.beforeWebKit(key))
      XCTAssertFalse(lab.beforeWebKitDown(key))
      XCTAssertTrue(lab.recordFlutter(key, webViewFocused: true))
    }
    XCTAssertEqual(lab.suppressed, 0, "P must not apply a laboratory guard")
    XCTAssertEqual(lab.routed, 0)
  }

  func testHostUsesThePackageControllerAndWindow() {
    let window = NSApplication.shared.windows.compactMap { $0 as? MainFlutterWindow }.first
    XCTAssertNotNil(window)
    let packageWindow: WebViewKeyGuardWindow? = window
    let labHost = packageWindow?.contentViewController?.children.first as? WebCommandHostController
    XCTAssertNotNil(labHost)
    let controller = labHost?.children.first as? WebViewKeyGuardFlutterViewController
    XCTAssertTrue(controller is LabFlutterViewController)
  }

  func testTraceSamplesRepeatedEscapeCallersWithBoundedHistory() {
    let trace = NativeKeyTrace(captureStacks: true)
    let key = event(53, mask: 8)
    for _ in 0..<256 { trace.record("wk.equivalent.in", key) }
    let samples = trace.snapshot["stackSamples"] as! [[String: Any]]
    XCTAssertEqual(samples.map { $0["visit"] as! Int }, [1, 2, 3, 16, 128])
    XCTAssertFalse((samples.first!["stack"] as! [String]).isEmpty)
    for n in 1...40 { trace.record("window.sendEvent", event(timestamp: Double(n))) }
    XCTAssertEqual((trace.snapshot["eventStarts"] as! [[[String: Any]]]).count, 32)
  }

}
