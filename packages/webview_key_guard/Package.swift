// swift-tools-version: 5.9
import PackageDescription

// Tests the native policy without launching Flutter or changing the active app.
let package = Package(
  name: "WebViewKeyGuardCore",
  platforms: [.macOS(.v10_15)],
  products: [.library(name: "WebViewKeyGuardCore", targets: ["WebViewKeyGuardCore"])],
  targets: [
    .target(name: "WebViewKeyGuardCore",
            path: "macos/webview_key_guard/Sources/webview_key_guard/Core"),
    .testTarget(name: "WebViewKeyGuardCoreTests", dependencies: ["WebViewKeyGuardCore"],
                path: "macos/Tests"),
  ]
)
