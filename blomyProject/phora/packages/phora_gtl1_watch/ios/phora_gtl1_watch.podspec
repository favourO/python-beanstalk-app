Pod::Spec.new do |s|
  s.name             = 'phora_gtl1_watch'
  s.version          = '0.0.1'
  s.summary          = 'Phora GTL1 watch wrapper'
  s.description      = <<-DESC
Native GTL1 watch wrapper for Flutter using Starmax and RunmefitSDK.
                       DESC
  s.homepage         = 'https://phora.app'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Phora' => 'team@phora.app' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.frameworks = 'CoreBluetooth'
  s.vendored_frameworks = 'Frameworks/RunmefitSDK.framework'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
