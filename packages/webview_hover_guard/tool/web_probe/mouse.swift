// mouse <check|pos|move x y|click x y|rclick x y>  (global display coords, top-left origin)
import CoreGraphics
import Foundation
let a = CommandLine.arguments
func post(_ t: CGEventType, _ p: CGPoint, _ b: CGMouseButton = .left) {
  CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: p, mouseButton: b)!.post(tap: .cghidEventTap)
}
switch a[1] {
case "check": print("postAccess=\(CGPreflightPostEventAccess())")
case "pos": let p = CGEvent(source: nil)!.location; print(Int(p.x), Int(p.y))
case "move": post(.mouseMoved, CGPoint(x: Double(a[2])!, y: Double(a[3])!))
case "click": let p = CGPoint(x: Double(a[2])!, y: Double(a[3])!); post(.mouseMoved, p); usleep(80_000); post(.leftMouseDown, p); usleep(60_000); post(.leftMouseUp, p)
case "rclick": let p = CGPoint(x: Double(a[2])!, y: Double(a[3])!); post(.mouseMoved, p, .right); usleep(80_000); post(.rightMouseDown, p, .right); usleep(60_000); post(.rightMouseUp, p, .right)
default: print("?")
}
