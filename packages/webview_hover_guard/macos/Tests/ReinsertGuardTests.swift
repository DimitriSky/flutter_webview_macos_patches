import Cocoa
import XCTest
@testable import WebViewHoverGuardCore

final class ReinsertGuardTests: XCTestCase {
  // Each test patches its own class: a patch stays on its class for the process lifetime.
  final class HostA: NSView {}
  final class HostB: NSView {}
  final class HostC: NSView {}
  final class HostD: NSView {}
  final class Plain: NSView {}

  /// Counts window re-attachments: WebKit reacts to these (viewDidMoveToWindow).
  final class Child: NSView {
    var attaches = 0
    override func viewDidMoveToWindow() { if window != nil { attaches += 1 } }
  }

  /// A real window: outside a window AppKit does not report the re-add at all.
  private func mounted<T: NSView>(_ host: T) -> (NSWindow, T) {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: [.borderless], backing: .buffered, defer: true)
    window.contentView!.addSubview(host)
    return (window, host)
  }

  /// Like FlutterMutatorView: the platform view container with the tracking-area
  /// container above it. Only then is a re-add a real reorder in AppKit.
  private func attach(_ child: NSView, to host: NSView) {
    host.addSubview(child)
    host.addSubview(NSView())
  }

  func testUnpatchedAppKitReAttachesOnReAdd() {
    let (window, host) = mounted(Plain())
    let child = Child()
    attach(child, to: host)
    host.addSubview(child) // what the engine does on every frame
    XCTAssertEqual(child.attaches, 2, "the AppKit behavior that causes the bug")
    _ = window
  }

  func testSkipsReAddOfExistingSubview() {
    let guardian = ReinsertGuard()
    guardian.install(on: HostA.self)
    let (window, host) = mounted(HostA())
    let child = Child()
    attach(child, to: host)
    host.addSubview(child)
    host.addSubview(child)
    XCTAssertEqual(child.attaches, 1)
    XCTAssertEqual(guardian.skipped, 2)
    XCTAssertTrue(child.superview === host)
    _ = window
  }

  func testRealMoveToAnotherSuperviewStillWorks() {
    let guardian = ReinsertGuard()
    guardian.install(on: HostB.self)
    let (window, a) = mounted(HostB())
    let b = HostB()
    window.contentView!.addSubview(b)
    let child = Child()
    a.addSubview(child)
    b.addSubview(child)
    XCTAssertTrue(child.superview === b)
    XCTAssertEqual(guardian.skipped, 0)
  }

  func testDisabledGuardAndUnpatchedClassesKeepAppKitBehavior() {
    let guardian = ReinsertGuard()
    guardian.install(on: HostC.self)
    guardian.enabled = false
    let (window, host) = mounted(HostC())
    let child = Child()
    attach(child, to: host)
    host.addSubview(child)
    XCTAssertEqual(child.attaches, 2)
    XCTAssertEqual(guardian.skipped, 0)

    // NSView itself is not patched.
    let plain = Plain(), other = Child()
    window.contentView!.addSubview(plain)
    attach(other, to: plain)
    plain.addSubview(other)
    XCTAssertEqual(other.attaches, 2)
  }

  func testInstallIsIdempotentAndMissingClassesAreReported() {
    let guardian = ReinsertGuard()
    guardian.install(on: HostD.self)
    guardian.install(on: HostD.self)
    XCTAssertEqual(guardian.patchedClassNames.count, 1)
    guardian.installForFlutter() // no Flutter engine in this test process
    XCTAssertEqual(guardian.missingClassNames, ReinsertGuard.flutterClassNames)
  }
}
