// Real-mouse reproduction of the hover jump without Flutter, and check of the fix.
//
// Builds the view tree FlutterMutatorView builds for a platform view, puts a WKWebView
// 84 pt below the window top (title bar + app toolbar), rests the real mouse on the
// first menu item and then does what the engine does on every frame.
//
//   swiftc -O tool/hover_harness/main.swift \
//     macos/webview_hover_guard/Sources/webview_hover_guard/Core/ReinsertGuard.swift -o /tmp/hover_harness
//   /tmp/hover_harness <direct|wrapped> <unguarded|guarded>
//
// direct  = WKWebView is the platform view (webview_flutter)
// wrapped = WKWebView inside an NSView (flutter_inappwebview)
// Needs Accessibility permission for the process that runs it (it moves the mouse).
// Exit code 0 = hover stayed on the item under the mouse, 1 = hover jumped (the bug).
import Cocoa
import WebKit

func log(_ s: String) { print(String(format: "%7.2f ", ProcessInfo.processInfo.systemUptime.truncatingRemainder(dividingBy: 1000)) + s); fflush(stdout) }

class Flipped: NSView { override var isFlipped: Bool { true } }
/// Stands for FlutterMutatorView; the only class the guard patches here.
final class FakeMutatorView: Flipped {}
final class KeyWindow: NSWindow { override var canBecomeKey: Bool { true }; override var canBecomeMain: Bool { true } }

let args = CommandLine.arguments
guard args.count == 3, ["direct", "wrapped"].contains(args[1]), ["unguarded", "guarded"].contains(args[2]) else {
  print("usage: hover_harness <direct|wrapped> <unguarded|guarded>")
  exit(2)
}
let wrapped = args[1] == "wrapped"
let guarded = args[2] == "guarded"
let topInset: CGFloat = 84
let size = NSSize(width: 500, height: 400)
let windowTopLeft = CGPoint(x: 100, y: 100) // global coordinates, top-left origin

final class Harness: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
  let window: KeyWindow
  let mutator = FakeMutatorView()
  let container = Flipped()
  let trackingAreaContainer = Flipped()
  let wrapper = Flipped()
  var web: WKWebView!
  var jumped = false

  override init() {
    let screenHeight = NSScreen.screens[0].frame.height
    let height = size.height + topInset
    window = KeyWindow(contentRect: NSRect(x: windowTopLeft.x, y: screenHeight - windowTopLeft.y - height, width: size.width, height: height),
                       styleMask: [.borderless], backing: .buffered, defer: false)
    super.init()
    let config = WKWebViewConfiguration()
    config.userContentController.add(self, name: "probe")
    web = WKWebView(frame: NSRect(origin: .zero, size: size), configuration: config)
    web.navigationDelegate = self
    let root = Flipped(frame: NSRect(x: 0, y: 0, width: size.width, height: height))
    root.wantsLayer = true
    root.layer?.backgroundColor = NSColor.systemYellow.cgColor // the app toolbar
    window.contentView = root
    mutator.frame = NSRect(x: 0, y: topInset, width: size.width, height: size.height)
    mutator.wantsLayer = true
    root.addSubview(mutator)
    container.frame = mutator.bounds
    container.wantsLayer = true
    mutator.addSubview(container)
    if wrapped {
      wrapper.frame = mutator.bounds
      web.autoresizingMask = [.width, .height]
      wrapper.addSubview(web)
      container.addSubview(wrapper)
    } else {
      container.addSubview(web)
    }
    trackingAreaContainer.frame = mutator.bounds
    mutator.addSubview(trackingAreaContainer)
    if guarded { ReinsertGuard.shared.install(on: FakeMutatorView.self) }
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
    web.loadHTMLString(Self.html, baseURL: nil)
  }

  static let html = """
  <style>body{margin:0}button{display:block;width:300px;height:41px;margin:0;border:0} button:hover{background:#000;color:#fff}</style>
  <div style="height:100px"></div><button id=edit>Edit text</button><button id=add>Add reference</button><button id=del>Delete block</button>
  <script>
  document.addEventListener('mouseover', e => webkit.messageHandlers.probe.postMessage(JSON.stringify({tgt: e.target.id || e.target.nodeName, y: e.clientY})), true);
  </script>
  """

  func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
    log("page mouseover \(m.body)")
    if resting, let body = m.body as? String, !body.contains("\"edit\"") { jumped = true }
  }

  var resting = false

  func post(_ p: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)!.post(tap: .cghidEventTap)
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    // The first item spans page y 100...141; rest the mouse at page y 120.
    let target = CGPoint(x: windowTopLeft.x + 60, y: windowTopLeft.y + topInset + 120)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.post(CGPoint(x: target.x, y: target.y - 6))
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        self.post(target)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.resting = true; log("mouse rests on Edit text") }
      }
    }
    for n in 1...3 { DispatchQueue.main.asyncAfter(deadline: .now() + 1.5 + Double(n) * 0.7) { self.frame(n) } }
    DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
      let verdict = self.jumped ? "FAIL: hover jumped away from the item under the mouse" : "PASS: hover stayed under the mouse"
      log("\(args[1]) \(args[2]): \(verdict)" + (guarded ? " (skipped re-adds: \(ReinsertGuard.shared.skipped))" : ""))
      exit(self.jumped ? 1 : 0)
    }
  }

  /// FlutterMutatorView.applyFlutterLayer, as far as the view tree goes.
  func frame(_ n: Int) {
    log("frame \(n)")
    mutator.addSubview(container)
    container.frame = mutator.bounds
    container.subviews.first?.frame = NSRect(origin: .zero, size: size)
    container.layer?.sublayerTransform = CATransform3DIdentity
    mutator.addSubview(trackingAreaContainer, positioned: .above, relativeTo: nil)
    trackingAreaContainer.frame = mutator.bounds
  }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let harness = Harness()
app.run()
