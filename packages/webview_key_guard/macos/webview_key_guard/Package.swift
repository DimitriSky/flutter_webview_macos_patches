// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "webview_key_guard",
  platforms: [.macOS("10.15")],
  products: [.library(name: "webview-key-guard", targets: ["webview_key_guard"])],
  dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
  targets: [
    .target(
      name: "webview_key_guard",
      dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")],
      resources: [.process("PrivacyInfo.xcprivacy")]
    ),
  ]
)
