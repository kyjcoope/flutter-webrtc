#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_webrtc'
  s.version          = '0.12.6'
  s.summary          = 'Flutter WebRTC plugin for macOS.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'https://github.com/cloudwebrtc/flutter-webrtc'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'CloudWebRTC' => 'duanweiwei1982@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*', '../common/cpp/include/buffer/*.h', '../common/cpp/src/buffer/*.cpp'
  s.library = 'c++', 'pthread'

  s.dependency 'FlutterMacOS'
  s.dependency 'WebRTC-SDK', '125.6422.06'
  s.osx.deployment_target = '10.14'
end
