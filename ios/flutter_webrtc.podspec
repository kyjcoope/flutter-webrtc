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
  s.ios.deployment_target = '13.0'
  s.source_files = 'Classes/**/*.{h,m,mm,swift}'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'WebRTC-SDK', '125.6422.06'
  s.dependency "#{s.name}/Core"
  s.subspec 'Core' do |ss|
    ss.source_files = 'src/**/*.{h,hpp,c,cpp}'
    ss.public_header_files = 'src/native_buffer_api.h'
    ss.private_header_files = 'src/**/*.h', 'src/internal/*.h'
    ss.pod_target_xcconfig = {
      'CLANG_CXX_LIBRARY' => 'libc++',
      'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) DART_API_DL_IMPLEMENTATION=1',
      'USER_HEADER_SEARCH_PATHS' => "$(inherited) \"$(PODS_TARGET_SRCROOT)/src\""
    }
    ss.compiler_flags = '-std=c++14'
    ss.libraries = 'c++', 'pthread'
  end
  s.static_framework = true
end