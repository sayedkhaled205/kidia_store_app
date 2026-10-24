#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint kashier_flutter_sdk.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'kashier_flutter_sdk'
  s.version          = '0.1.1'
  s.summary          = 'Kashier payment SDK for Flutter — Card, Apple Pay, and mobile wallet payments in Egypt.'
  s.description      = <<-DESC
Kashier payment SDK for Flutter. Accept Card, Apple Pay, and mobile wallet
payments in Egypt with a prebuilt, localized (EN/AR) payment sheet.
                       DESC
  s.homepage         = 'https://kashier.io'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Kashier' => 'support@kashier.io' }
  s.source           = { :git => 'https://github.com/kashier/kashier-flutter-sdk.git', :tag => s.version.to_s }
  s.source_files = 'Classes/**/*'
  s.frameworks = 'PassKit'
  s.dependency 'Flutter'
  s.platform = :ios, '14.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'kashier_flutter_sdk_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
