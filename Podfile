source 'https://cdn.cocoapods.org/'
platform :osx, '12.0'

target 'Avro Keyboard'
pod 'RegexKitLite', '~> 4.0'
pod 'FMDB', '~> 2.1'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '12.0'
    end
  end
end
