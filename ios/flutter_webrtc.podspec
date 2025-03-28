# flutter_webrtc.podspec
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
    ss.source_files = 'Classes/**/*.{h,hpp,c,cpp}'
    ss.private_header_files = 'Classes/**/*.{h,hpp}'
    ss.pod_target_xcconfig = {
      'CLANG_CXX_LIBRARY' => 'libc++',
      'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) DART_API_DL_IMPLEMENTATION=1'
    }
    ss.compiler_flags = '-std=c++14'
    ss.libraries = 'c++', 'pthread'
  end
  s.static_framework = true
end