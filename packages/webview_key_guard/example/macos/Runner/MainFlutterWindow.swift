import Cocoa
import FlutterMacOS
import WebKit
import webview_key_guard

class MainFlutterWindow: WebCommandWindow {
  private var labBridge: LabBridge?

  override func sendEvent(_ event: NSEvent) {
    KeyboardExperiment.shared.recordTrace("window.sendEvent", event, receiver: self)
    super.sendEvent(event)
  }

  override func awakeFromNib() {
    keyGuardConfiguration.setEnabled(false)
    WKWebView.installKeyLabObservation()
    let flutterViewController = LabFlutterViewController()
    self.contentViewController = keyGuardHost(for: WebCommandHostController(
      content: flutterViewController, scope: webCommandScope))
    self.setContentSize(NSSize(width: 1150, height: 820))
    self.minSize = NSSize(width: 820, height: 680)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)
    labBridge = LabBridge(controller: flutterViewController)

    super.awakeFromNib()
  }
}
