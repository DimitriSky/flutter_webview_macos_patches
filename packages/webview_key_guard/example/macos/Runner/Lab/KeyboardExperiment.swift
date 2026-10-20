import Cocoa
import WebKit
import webview_key_guard

final class KeyboardExperiment {
  static let shared = KeyboardExperiment()
  private let packageConfiguration: WebViewKeyGuardConfiguration
  private(set) var strategy: KeyStrategy = BaselineStrategy()
  private(set) var run = ""
  private(set) var stopped = false
  private(set) var restartRequired = false
  private(set) var webKit = EventLedger()
  private(set) var webKitDown = EventLedger()
  private(set) var flutter = EventLedger()
  private(set) var routed = 0
  private(set) var suppressed = 0
  private var trace = NativeKeyTrace()
  var equivalentDepth = 0
  let webKitObservationEnabled = ProcessInfo.processInfo.environment["KEY_LAB_WEBKIT_OBSERVATION"] != "off"

  init(packageConfiguration: WebViewKeyGuardConfiguration = .shared) {
    self.packageConfiguration = packageConfiguration
  }

  func configure(id: String, run: String) -> Bool {
    guard !restartRequired, let strategy = makeKeyStrategy(id) else { return false }
    self.strategy = strategy
    packageConfiguration.setEnabled(strategy.usesCurrentPackage)
    self.run = run
    stopped = false
    webKit = EventLedger()
    webKitDown = EventLedger()
    flutter = EventLedger()
    routed = 0
    suppressed = 0
    trace = NativeKeyTrace()
    return true
  }

  func recordTrace(_ stage: String, _ event: NSEvent, detail: String = "", receiver: NSResponder? = nil) {
    trace.record(stage, event, detail: detail, depth: equivalentDepth, receiver: receiver)
  }

  func beforeWebKit(_ event: NSEvent, receiver: NSResponder? = nil) -> Bool {
    recordTrace("wk.equivalent.in", event, receiver: receiver)
    if stopped { return true }
    let seen = webKit.record(event)
    if tripIfLoop(webKit) { return true }
    if strategy.consumeBeforeWebKit(event, alreadySeen: seen) {
      suppressed += 1
      recordTrace("wk.equivalent.guard", event)
      return true
    }
    return false
  }

  func afterWebKit(_ event: NSEvent) -> Bool {
    let consume = strategy.consumeAfterWebKit(event)
    if consume { suppressed += 1 }
    recordTrace("wk.equivalent.out", event, detail: consume ? "consumed" : "passed")
    return consume
  }

  func beforeWebKitDown(_ event: NSEvent) -> Bool {
    if stopped { return true }
    let seen = webKitDown.record(event)
    if tripIfLoop(webKitDown) { return true }
    if strategy.guardsEveryStageIdentity && seen {
      suppressed += 1
      recordTrace("wk.keyDown.guard", event)
      return true
    }
    return false
  }

  func recordFlutter(_ event: NSEvent, webViewFocused: Bool) -> Bool {
    if stopped { return false }
    let seen = flutter.record(event)
    if tripIfLoop(flutter) { return false }
    if (strategy.guardsEveryStageIdentity || strategy.guardsFlutterIdentity) && webViewFocused && seen {
      suppressed += 1
      recordTrace("flutter.keyDown.guard", event)
      return false
    }
    return true
  }

  func didRoute() { routed += 1 }
  func stop() { stopped = true }

  private func tripIfLoop(_ ledger: EventLedger) -> Bool {
    // Emergency breaker is a failed run, never evidence that a strategy passed.
    if ledger.maximumVisits >= 256 {
      stopped = true
      restartRequired = true
    }
    return stopped
  }

  var snapshot: [String: Any] {
    ["run": run, "mode": strategy.id, "stopped": stopped,
     "implementation": strategy.usesCurrentPackage ? "webview_key_guard" : "lab",
     "packageEnabled": packageConfiguration.enabled,
     "restartRequired": restartRequired, "webKit": webKit.snapshot,
     "webKitDown": webKitDown.snapshot,
     "flutter": flutter.snapshot, "routed": routed, "suppressed": suppressed,
     "pid": ProcessInfo.processInfo.processIdentifier, "bundlePath": Bundle.main.bundlePath,
     "webKitObservationEnabled": webKitObservationEnabled]
      .merging(trace.snapshot) { _, latest in latest }
  }
}

extension WKWebView {
  static func installKeyLabObservation() {
    guard KeyboardExperiment.shared.webKitObservationEnabled else { return }
    let original = class_getInstanceMethod(WKWebView.self, #selector(performKeyEquivalent(with:)))!
    let replacement = class_getInstanceMethod(WKWebView.self, #selector(keyLabEquivalent(with:)))!
    method_exchangeImplementations(original, replacement)
    let originalDown = class_getInstanceMethod(WKWebView.self, #selector(keyDown(with:)))!
    let replacementDown = class_getInstanceMethod(WKWebView.self, #selector(keyLabDown(with:)))!
    method_exchangeImplementations(originalDown, replacementDown)
  }

  @objc private func keyLabDown(with event: NSEvent) {
    let lab = KeyboardExperiment.shared
    lab.recordTrace("wk.keyDown.in", event, receiver: self)
    if lab.beforeWebKitDown(event) { return }
    keyLabDown(with: event)
    lab.recordTrace("wk.keyDown.out", event)
  }

  @objc private func keyLabEquivalent(with event: NSEvent) -> Bool {
    let lab = KeyboardExperiment.shared
    lab.equivalentDepth += 1
    defer { lab.equivalentDepth -= 1 }
    if lab.beforeWebKit(event, receiver: self) { return true }
    let handled = keyLabEquivalent(with: event)
    lab.recordTrace("wk.equivalent.original", event, detail: handled ? "handled" : "unhandled")
    return lab.afterWebKit(event) || handled
  }
}
