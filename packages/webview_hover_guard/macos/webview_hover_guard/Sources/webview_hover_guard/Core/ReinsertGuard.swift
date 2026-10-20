import Cocoa
import ObjectiveC

/// Skips `addSubview:` when the view is already a subview of the receiver.
///
/// The Flutter macOS engine (FlutterMutatorView.applyFlutterLayer) re-adds the
/// container of every platform view on each rendered frame. AppKit then
/// re-evaluates tracking areas and WebKit gets the mouse position relative to the
/// window instead of the WKWebView: page hover jumps down by the web view's
/// top offset (and sideways by its left offset). Skipping the no-op re-add removes
/// that. A real move to another superview still goes through.
///
/// Only the given classes are patched; NSView itself is never changed.
public final class ReinsertGuard {
  public static let shared = ReinsertGuard()

  /// Engine classes whose `addSubview:` re-adds the platform view container.
  public static let flutterClassNames = ["FlutterMutatorView", "FlutterPathClipView"]

  public var enabled = true
  public private(set) var patchedClassNames: [String] = []
  public private(set) var missingClassNames: [String] = []
  public private(set) var skipped = 0

  private typealias AddSubview = @convention(c) (NSView, Selector, NSView) -> Void

  /// Patches the Flutter engine classes. Safe to call more than once.
  public func installForFlutter() {
    precondition(Thread.isMainThread)
    for name in Self.flutterClassNames where !patchedClassNames.contains(name) && !missingClassNames.contains(name) {
      if let cls = NSClassFromString(name) as? NSView.Type {
        install(on: cls, name: name)
      } else {
        // A newer engine may have renamed the class: nothing is patched, nothing breaks.
        missingClassNames.append(name)
      }
    }
  }

  /// Patches one class. Exposed for native tests and the reproduction harness.
  public func install(on cls: NSView.Type, name: String? = nil) {
    precondition(Thread.isMainThread)
    let label = name ?? NSStringFromClass(cls)
    guard !patchedClassNames.contains(label) else { return }
    let selector = #selector(NSView.addSubview(_:))
    guard let method = class_getInstanceMethod(cls, selector) else { return }
    // The inherited NSView implementation (or the class's own one) stays the fallback.
    let original = unsafeBitCast(method_getImplementation(method), to: AddSubview.self)
    // The patch outlives any caller, so it keeps its guard alive.
    let block: @convention(block) (NSView, NSView) -> Void = { view, subview in
      if self.enabled && subview.superview === view {
        self.skipped += 1
        return
      }
      original(view, selector, subview)
    }
    let imp = imp_implementationWithBlock(block)
    // Add an override on this class only; if it already overrides, replace that.
    if !class_addMethod(cls, selector, imp, method_getTypeEncoding(method)) {
      method_setImplementation(method, imp)
    }
    patchedClassNames.append(label)
  }

  public var status: [String: Any] {
    ["enabled": enabled, "patched": patchedClassNames, "missing": missingClassNames, "skipped": skipped]
  }
}
