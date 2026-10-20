import Foundation

/// App-local persistence, shared by protected windows. No backend or Flutter dependency.
public final class WebViewKeyGuardConfiguration {
  public static let shared = WebViewKeyGuardConfiguration()
  public static let storageKey = "webview_key_guard.enabled.v1"
  private let defaults: UserDefaults
  public private(set) var enabled: Bool
  private(set) var revision = 0

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    enabled = defaults.object(forKey: Self.storageKey) as? Bool ?? true
  }

  public func setEnabled(_ value: Bool) {
    guard enabled != value else { return }
    defaults.set(value, forKey: Self.storageKey)
    enabled = value
    revision += 1
  }
}
