# flutter_webrtc.podspec
require 'json'
require 'open3'
def find_flutter_root()
  flutter_root = ENV['FLUTTER_ROOT']
  return flutter_root unless flutter_root.nil? || flutter_root.empty?
  potential_paths = [
    File.expand_path('../../flutter', __dir__),
    File.expand_path('../../../flutter', __dir__),
    File.expand_path('../../../../flutter', __dir__)
  ]
  potential_paths.each do |path|
    if File.exist?(File.join(path, 'bin', 'flutter'))
      return path
    end
  end
  begin
    stdout, stderr, status = Open3.capture3('which flutter')
    if status.success?
      resolved_flutter = File.realpath(stdout.strip)
      flutter_root = File.dirname(File.dirname(resolved_flutter))
      if File.exist?(File.join(flutter_root, 'bin', 'cache', 'dart-sdk'))
        return flutter_root
      end
    end
  rescue StandardError => e
    # ignore
  end
  raise "Error: Could not locate Flutter SDK. Set FLUTTER_ROOT environment variable or ensure Flutter SDK is in a standard relative path."
end
FLUTTER_ROOT_PATH = find_flutter_root()
DART_SDK_INCLUDE_PATH = File.join(FLUTTER_ROOT_PATH, 'bin', 'cache', 'dart-sdk', 'include')
unless Dir.exist?(DART_SDK_INCLUDE_PATH)
  raise "Dart SDK include directory not found at expected path: #{DART_SDK_INCLUDE_PATH}. Please ensure Flutter SDK is correctly bootstrapped (`flutter doctor`)."
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
    'HEADER_SEARCH_PATHS' => "$(inherited) \"#{DART_SDK_INCLUDE_PATH}\"",
    'USER_HEADER_SEARCH_PATHS' => "$(inherited) \"$(PODS_TARGET_SRCROOT)/Classes\"",
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) DART_API_DL_IMPLEMENTATION=1'
  }
  s.static_framework = true
  s.libraries = 'c++', 'pthread'
end