#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
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
    'CLANG_CXX_LIBRARY' => 'libc++',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) DART_API_DL_IMPLEMENTATION=1'
  }
  s.compiler_flags = '-std=c++14'
  s.static_framework = true
  s.libraries = 'c++', 'pthread'
end
