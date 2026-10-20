Pod::Spec.new do |s|
  s.name             = 'webview_key_guard'
  s.version          = '0.1.0'
  s.summary          = 'Optional macOS WebView keyboard redispatch protection.'
  s.description      = 'B3 command-boundary and focused Flutter key routing with a persistent off switch.'
  s.homepage         = 'https://github.com/DimitriSky/flutter_webview_key_guard'
  s.license          = { :type => 'Proprietary' }
  s.author           = 'WebView Key Guard contributors'
  s.source           = { :path => '.' }
  s.source_files     = 'webview_key_guard/Sources/webview_key_guard/**/*.swift'
  s.resource_bundles = {
    'webview_key_guard_privacy' => ['webview_key_guard/Sources/webview_key_guard/PrivacyInfo.xcprivacy']
  }
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
