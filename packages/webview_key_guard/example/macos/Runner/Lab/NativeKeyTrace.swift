import Cocoa

// Observation only: timestamps below measure callback arrival, not event creation.
final class NativeKeyTrace {
  private let started = ProcessInfo.processInfo.systemUptime
  private let captureStacks: Bool
  private var sequence = 0
  private var recent: [[String: Any]] = []
  private var first: [[String: Any]] = []
  private var eventOrder: [String] = []
  private var eventStarts: [String: [[String: Any]]] = [:]
  private var stackVisits: [String: Int] = [:]
  private var stacks: [[String: Any]] = []

  init(captureStacks: Bool = ProcessInfo.processInfo.environment["KEY_LAB_TRACE_STACKS"] != "off") {
    self.captureStacks = captureStacks
  }

  func record(_ stage: String, _ event: NSEvent, detail: String = "",
              depth: Int = 0, receiver: NSResponder? = nil) {
    guard [.keyDown, .keyUp, .flagsChanged].contains(event.type) else { return }
    sequence += 1
    let pointer = String(describing: Unmanaged.passUnretained(event).toOpaque())
    let key = "\(pointer):\(event.timestamp):\(event.type.rawValue)"
    let row: [String: Any] = [
      "sequence": sequence, "observedMs": (ProcessInfo.processInfo.systemUptime - started) * 1000,
      "stage": stage, "detail": detail, "keyCode": Int(event.keyCode),
      "timestamp": event.timestamp, "modifiers": Int(event.modifierFlags.rawValue),
      "repeat": event.type == .keyDown ? event.isARepeat : false,
      "type": Int(event.type.rawValue), "object": pointer,
      "equivalentDepth": depth,
      "firstResponder": event.window?.firstResponder.map { String(describing: type(of: $0)) } ?? "none",
    ]
    if first.count < 96 { first.append(row) }
    recent.append(row)
    if recent.count > 512 { recent.removeFirst() }
    if eventStarts[key] == nil {
      eventOrder.append(key)
      eventStarts[key] = []
      if eventOrder.count > 32 { eventStarts.removeValue(forKey: eventOrder.removeFirst()) }
    }
    if eventStarts[key]!.count < 32 { eventStarts[key]!.append(row) }

    guard captureStacks, event.keyCode == 53,
          ["window.sendEvent", "wk.equivalent.in", "wk.keyDown.in",
           "flutter.keyDown.in", "flutter.keyDown.route"].contains(stage) else { return }
    let visitKey = "\(key):\(stage)"
    let visit = (stackVisits[visitKey] ?? 0) + 1
    if stackVisits.count > 1024 { stackVisits.removeAll() }
    stackVisits[visitKey] = visit
    guard [1, 2, 3, 16, 128].contains(visit) else { return }
    var sample = row
    sample["visit"] = visit
    sample["stack"] = Array(Thread.callStackSymbols.prefix(40))
    sample["responderChain"] = responderChain(receiver ?? event.window?.firstResponder)
    stacks.append(sample)
    if stacks.count > 64 { stacks.removeFirst() }
  }

  private func responderChain(_ first: NSResponder?) -> [String] {
    var current = first
    var visited = Set<ObjectIdentifier>()
    var chain: [String] = []
    while let responder = current, chain.count < 16 {
      guard visited.insert(ObjectIdentifier(responder)).inserted else {
        chain.append("cycle")
        break
      }
      chain.append("\(type(of: responder))@\(Unmanaged.passUnretained(responder).toOpaque())")
      current = responder.nextResponder
    }
    return chain
  }

  var snapshot: [String: Any] {
    ["trace": recent, "firstTrace": first,
     "eventStarts": eventOrder.map { eventStarts[$0]! }, "stackSamples": stacks,
     "traceStacksEnabled": captureStacks, "traceRecordCount": sequence]
  }
}
