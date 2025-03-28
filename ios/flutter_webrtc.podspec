# flutter_webrtc.podspec
FLUTTER_ROOT = ENV['FLUTTER_ROOT']
if FLUTTER_ROOT.nil? || FLUTTER_ROOT.empty?
  raise "FLUTTER_ROOT environment variable is not set. Make sure you are building using Flutter tools (e.g., `flutter run ios`)."
end
DART_SDK_INCLUDE_PATH = File.expand_path(File.join(FLUTTER_ROOT, 'bin', 'cache', 'dart-sdk', 'include'))
unless Dir.exist?(DART_SDK_INCLUDE_PATH)
  raise "Dart SDK include directory not found at: #{DART_SDK_INCLUDE_PATH}. Ensure Flutter SDK at #{FLUTTER_ROOT} is correctly bootstrapped (`flutter doctor`)."
end
Pod::Spec.new do |s|
  s.name             = 'flutter_webrtc'
  s.version          = '0.12.6'
  s.summary          = 'Flutter WebRTC plugin for iOS.'
  s.description      = <<-DESC
Flutter WebRTC plugin with native C++ buffer implementation.
                       DESC
  s.homepage         = 'https://github.com/cloudwebrtc/flutter-webrtc'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'CloudWebRTC' => 'duanweiwei1982@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*.{h,m,mm,swift,c,cpp}'
  s.public_header_files = 'Classes/**/*.h'
  s.private_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'WebRTC-SDK', '125.6422.06'
  s.ios.deployment_target = '13.0'
  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => "$(inherited) \"#{DART_SDK_INCLUDE_PATH}\" \"$(PODS_TARGET_SRCROOT)/Classes\"",
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) DART_API_DL_IMPLEMENTATION=1'
  }
  s.static_framework = true
  s.libraries = 'c++', 'pthread'
end