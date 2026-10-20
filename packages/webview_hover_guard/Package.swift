// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "WebViewHoverGuardCore",
  platforms: [.macOS(.v10_15)],
  products: [.library(name: "WebViewHoverGuardCore", targets: ["WebViewHoverGuardCore"])],
  targets: [
    .target(name: "WebViewHoverGuardCore", path: "macos/webview_hover_guard/Sources/webview_hover_guard/Core"),
    .testTarget(name: "WebViewHoverGuardCoreTests", dependencies: ["WebViewHoverGuardCore"], path: "macos/Tests"),
  ]
)
