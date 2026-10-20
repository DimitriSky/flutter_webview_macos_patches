import Cocoa

protocol KeyStrategy {
  var id: String { get }
  var usesCurrentPackage: Bool { get }
  var routesWebViewOutsideFlutter: Bool { get }
  var routesKeyUpAndFlags: Bool { get }
  var guardsEveryStageIdentity: Bool { get }
  var guardsFlutterIdentity: Bool { get }
  var isolatesNativeCommandFallback: Bool { get }
  func consumeBeforeWebKit(_ event: NSEvent, alreadySeen: Bool) -> Bool
  func consumeAfterWebKit(_ event: NSEvent) -> Bool
}

extension KeyStrategy {
  var usesCurrentPackage: Bool { false }
  var routesWebViewOutsideFlutter: Bool { false }
  var routesKeyUpAndFlags: Bool { false }
  var guardsEveryStageIdentity: Bool { false }
  var guardsFlutterIdentity: Bool { false }
  var isolatesNativeCommandFallback: Bool { false }
  func consumeBeforeWebKit(_ event: NSEvent, alreadySeen: Bool) -> Bool { false }
  func consumeAfterWebKit(_ event: NSEvent) -> Bool { false }
}

struct BaselineStrategy: KeyStrategy { let id = "0" }

struct CurrentPackageStrategy: KeyStrategy {
  let id = "P"
  let usesCurrentPackage = true
}

struct EnterOnlyStrategy: KeyStrategy {
  let id = "A"
  func consumeAfterWebKit(_ event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
    return event.type == .keyDown && modifiers == .command && [36, 76].contains(event.keyCode)
  }
}

struct ResponderRoutingStrategy: KeyStrategy {
  let id = "B"
  let routesWebViewOutsideFlutter = true
  let routesKeyUpAndFlags = true
}

struct KeyDownRoutingStrategy: KeyStrategy {
  let id = "B1"
  let routesWebViewOutsideFlutter = true
}

struct GuardedKeyDownRoutingStrategy: KeyStrategy {
  let id = "B2"
  let routesWebViewOutsideFlutter = true
  let guardsFlutterIdentity = true
}

struct EventIdentityStrategy: KeyStrategy {
  let id = "C"
  func consumeBeforeWebKit(_ event: NSEvent, alreadySeen: Bool) -> Bool { alreadySeen }
}

struct CommandBoundaryRoutingStrategy: KeyStrategy {
  let id = "B3"
  let routesWebViewOutsideFlutter = true
  let guardsFlutterIdentity = true
  let isolatesNativeCommandFallback = true
}

struct FullIdentityStrategy: KeyStrategy {
  let id = "C2"
  let guardsEveryStageIdentity = true
  func consumeBeforeWebKit(_ event: NSEvent, alreadySeen: Bool) -> Bool { alreadySeen }
}

// These strategies change the host or the page, not native key-equivalent handling.
struct NativeWindowStrategy: KeyStrategy { let id = "D" }
struct JavaScriptStrategy: KeyStrategy { let id = "E" }

func makeKeyStrategy(_ id: String) -> KeyStrategy? {
  switch id {
  case "P": return CurrentPackageStrategy()
  case "0": return BaselineStrategy()
  case "A": return EnterOnlyStrategy()
  case "B": return ResponderRoutingStrategy()
  case "B1": return KeyDownRoutingStrategy()
  case "B2": return GuardedKeyDownRoutingStrategy()
  case "B3": return CommandBoundaryRoutingStrategy()
  case "C": return EventIdentityStrategy()
  case "C2": return FullIdentityStrategy()
  case "D": return NativeWindowStrategy()
  case "E": return JavaScriptStrategy()
  default: return nil
  }
}
