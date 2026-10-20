import Cocoa

final class EventLedger {
  private let objects = NSHashTable<NSEvent>(options: [.weakMemory, .objectPointerPersonality])
  private var visits: [String: Int] = [:]
  private(set) var calls = 0
  private(set) var duplicateObjects = 0
  private(set) var maximumVisits = 0
  private(set) var recent: [[String: Any]] = []

  func record(_ event: NSEvent) -> Bool {
    calls += 1
    let seen = objects.contains(event)
    objects.add(event)
    if seen { duplicateObjects += 1 }
    let isRepeat = event.type == .keyDown && event.isARepeat
    let key = "\(event.timestamp):\(event.keyCode):\(event.modifierFlags.rawValue):\(isRepeat)"
    let count = (visits[key] ?? 0) + 1
    visits[key] = count
    maximumVisits = max(maximumVisits, count)
    if visits.count > 4096 { visits = [key: count] }
    recent.append([
      "keyCode": Int(event.keyCode), "timestamp": event.timestamp,
      "modifiers": Int(event.modifierFlags.rawValue), "repeat": isRepeat,
      "duplicateObject": seen, "visits": count,
    ])
    if recent.count > 12 { recent.removeFirst() }
    return seen
  }

  var snapshot: [String: Any] {
    ["calls": calls, "duplicateObjects": duplicateObjects,
     "maximumVisits": maximumVisits, "recent": recent]
  }
}
