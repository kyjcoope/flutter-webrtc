require 'json'

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
    require 'open3'
    stdout, stderr, status = Open3.capture3('which flutter')
    if status.success?
      resolved_flutter = File.realpath(stdout.strip)
      flutter_root = File.dirname(File.dirname(resolved_flutter))
      if File.exist?(File.join(flutter_root, 'bin', 'cache', 'dart-sdk'))
        return flutter_root
      end
    end
  rescue StandardError => e
    puts "Warning: Error trying to find Flutter via 'which': #{e.message}"
  end


  raise "Error: Could not locate Flutter SDK. Set FLUTTER_ROOT environment variable or ensure Flutter SDK is in a standard relative path."
end

FLUTTER_ROOT = find_flutter_root()
DART_SDK_PATH = File.join(FLUTTER_ROOT, 'bin', 'cache', 'dart-sdk')

unless Dir.exist?(File.join(DART_SDK_PATH, 'include'))
  raise "Dart SDK include directory not found: #{File.join(DART_SDK_PATH, 'include')}. Please ensure Flutter SDK is correctly bootstrapped (`flutter doctor`)."
end

Pod::Spec.new do |s|
  s.name             = 'flutter_webrtc'
  s.version          = '0.12.6'
  s.summary          = 'Flutter WebRTC plugin for iOS.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'https://github.com/cloudwebrtc/flutter-webrtc'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'CloudWebRTC' => 'duanweiwei1982@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'WebRTC-SDK', '125.6422.06'
  s.ios.deployment_target = '13.0'
  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => "$(inherited) \"#{DART_SDK_PATH}/include\"",
    'USER_HEADER_SEARCH_PATHS' => "$(inherited) \"$(PODS_TARGET_SRCROOT)/../src/main/cpp\"",
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) DART_API_DL_IMPLEMENTATION=1'
  }
  s.static_framework = true
  s.library = 'c++', 'pthread'
end