#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_webrtc'
  s.version          = '1.2.0'
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
  s.exclude_files = ['Classes/native_buffer_api.h', 'Classes/NativeBuffer.h', 'Classes/dart_api*.h', 'Classes/dart_native_api.h', 'Classes/dart_tools_api.h', 'Classes/dart_version.h', 'Classes/internal/**']
  s.dependency 'Flutter'
  s.dependency 'WebRTC-SDK', '137.7151.04'
  s.ios.deployment_target = '13.0'
  s.static_framework = true
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'USER_HEADER_SEARCH_PATHS' => 'Classes/**/*.h',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES'
  }
  s.libraries = 'c++'
end
