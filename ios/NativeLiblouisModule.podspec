Pod::Spec.new do |s|
  s.name         = 'NativeLiblouisModule'
  s.module_name  = 'NativeLiblouisModule'

  s.version      = '0.3.8'
  s.summary      = 'Expo Swift wrapper around liblouis.'
  s.description  = 'On‑device UEB Grade 1 & 2 Braille translation and back‑translation.'
  s.homepage     = 'https://github.com/hen1227/native-liblouis'
  s.license          = { :type => 'LGPL-2.1-or-later', :file => 'LICENSE' }
  s.author       = { 'Henry Abrahamsen' => 'henhen1227@gmail.com' }
#   s.source       = { :path => './ios' }
  s.source       = { :path => '.' }

  # ---- platform & build ----------------------------------------------------
  s.platform        = :ios, '13.0'
  s.swift_version   = '5.9'
  s.static_framework = true                # Expo autolinking prefers static

  # ---- source --------------------------------------------------------------
#   s.source_files = 'ios/**/*.{swift,h,m}'
  s.source_files = '**/*.{swift,h,m}'

  # pre‑built binary you dropped in ios/liblouis.framework
#   s.vendored_frameworks = 'ios/liblouis.xcframework'
  s.vendored_frameworks = 'liblouis.xcframework'

  # ExpoModulesCore for Module / Function DSL
  s.dependency 'ExpoModulesCore'

  # bundle the .ctb tables so lou_* can find them
  s.resource_bundles = {
#     'NativeLiblouisModule' => ['ios/liblouis_assets/**']
    'NativeLiblouisModule' => ['liblouis_assets/**']
  }

  # make the Swift module visible & link liblouis
  s.pod_target_xcconfig = {
    'DEFINES_MODULE'         => 'YES',
    'SWIFT_INCLUDE_PATHS'    => '$(PODS_TARGET_SRCROOT)/ios',
    'FRAMEWORK_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/ios',
#     'OTHER_LDFLAGS'          => '-framework "liblouis"'
  }
end
