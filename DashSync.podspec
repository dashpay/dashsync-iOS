#
# Run the following command to validate the podspec
# pod lib lint DashSync.podspec --no-clean --verbose --allow-warnings
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'DashSync'
  s.version          = '0.1.0'
  s.summary          = 'Dash Sync is a light and configurable blockchain client that you can embed into your iOS Application.'
  s.description      = 'Dash Sync is a light blockchain client that you can embed into your iOS Application.  It is fully customizable to make the type of node you are interested in.'

  s.homepage         = 'https://github.com/dashevo/dashsync-ios.git'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'quantumexplorer' => 'quantum@dash.org' }
  s.source           = { :git => 'https://github.com/dashevo/dashsync-iOS.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  
  s.requires_arc = true

  s.source_files = "DashSync/shared/**/*.{h,m,mm}"
  s.public_header_files = 'DashSync/shared/**/*.h'
  s.ios.source_files = "DashSync/iOS/**/*.{h,m,mm}"
  s.ios.public_header_files = 'DashSync/iOS/**/*.h'
  s.macos.source_files = "DashSync/macOS/**/*.{h,m,mm}"
  s.macos.public_header_files = 'DashSync/macOS/**/*.h'
  s.libraries = 'resolv', 'bz2', 'sqlite3'
  s.resource_bundles = {'DashSync' => ['DashSync/shared/*.xcdatamodeld', 'DashSync/shared/MappingModels/*.xcmappingmodel', 'DashSync/shared/*.plist', 'DashSync/shared/*.lproj', 'DashSync/shared/MasternodeLists/*.dat', 'DashSync/shared/*.json']}
  
  s.framework = 'Foundation', 'SystemConfiguration', 'CoreData', 'BackgroundTasks', 'Security'
  s.ios.framework = 'UIKit'
  s.macos.framework = 'Cocoa'
  s.compiler_flags = '-Wno-comma'
  s.dependency 'DashSharedCore', '0.4.19'
  s.dependency 'CocoaLumberjack', '3.7.2'
  s.ios.dependency 'DWAlertController', '0.2.1'
  s.dependency 'DSDynamicOptions', '0.1.2'
  s.prefix_header_contents = '#import "DSEnvironment.h"'
  
end

#Pod::Spec.new do |s|
#  s.name             = 'DashSync'
#  s.version          = '0.1.0'
#  s.summary          = 'Dash Sync is a light and configurable blockchain client that you can embed into your iOS Application.'
#  s.description      = 'Dash Sync is a light blockchain client that you can embed into your iOS Application.  It is fully customizable to make the type of node you are interested in.'
#
#  s.homepage         = 'https://github.com/dashevo/dashsync-ios.git'
#  s.license          = { :type => 'MIT', :file => 'LICENSE' }
#  s.author           = { 'quantumexplorer' => 'quantum@dash.org' }
#  s.source           = { :git => 'https://github.com/dashevo/dashsync-iOS.git', :tag => s.version.to_s }
#
#  s.ios.deployment_target = '13.0'
#  s.osx.deployment_target = '10.15'
#  
#  s.requires_arc = true
#
#  s.source_files = "DashSync/shared/**/*.{h,m,mm}", "../../dash-shared-core-ferment/dash_spv_apple_bindings/target/include/*.{h,m,mm}"
#  s.public_header_files = 'DashSync/shared/**/*.h', "../../dash-shared-core-ferment/dash_spv_apple_bindings/target/include/*.{h,m,mm}"
#  s.ios.source_files = "DashSync/iOS/**/*.{h,m,mm}", "../../dash-shared-core-ferment/dash_spv_apple_bindings/target/include/*.{h,m,mm}"
#  s.ios.public_header_files = 'DashSync/iOS/**/*.h', "../../dash-shared-core-ferment/dash_spv_apple_bindings/target/include/*.{h,m,mm}"
#  s.macos.source_files = "DashSync/macOS/**/*.{h,m,mm}", "../../dash-shared-core-ferment/dash_spv_apple_bindings/target/include/*.{h,m,mm}"
#  s.macos.public_header_files = 'DashSync/macOS/**/*.h', "../../dash-shared-core-ferment/dash_spv_apple_bindings/target/include/*.{h,m,mm}"
#  s.libraries = 'resolv', 'bz2', 'sqlite3'
##  s.ios.libraries = 'dash_spv_apple_bindings_ios'
##  s.macos.libraries = 'dash_spv_apple_bindings_macos'
#  s.resource_bundles = {'DashSync' => ['DashSync/shared/*.xcdatamodeld', 'DashSync/shared/MappingModels/*.xcmappingmodel', 'DashSync/shared/*.plist', 'DashSync/shared/*.lproj', 'DashSync/shared/MasternodeLists/*.dat', 'DashSync/shared/*.json']}
#  
#  s.framework = 'Foundation', 'SystemConfiguration', 'CoreData', 'BackgroundTasks', 'Security'
#  s.ios.framework = 'UIKit'
#  s.macos.framework = 'Cocoa'
#  s.compiler_flags = '-Wno-comma'
##  s.dependency 'DashSharedCore', '0.4.19'
#  s.dependency 'CocoaLumberjack', '3.7.2'
#  s.ios.dependency 'DWAlertController', '0.2.1'
#  s.dependency 'DSDynamicOptions', '0.1.2'
#  s.dependency 'DAPI-GRPC', '0.22.0-dev.8'
#  s.dependency 'TinyCborObjc', '0.4.6'
#  s.prefix_header_contents = '#import "DSEnvironment.h"'
#  s.ios.vendored_libraries = '../../dash-shared-core-ferment/dash_spv_apple_bindings/lib/ios/libdash_spv_apple_bindings_ios.a'
#  s.macos.vendored_libraries = '../../dash-shared-core-ferment/dash_spv_apple_bindings/lib/ios/libdash_spv_apple_bindings_macos.a'
#
##  s.vendored_frameworks = '../../dash-shared-core-ferment/dash_spv_apple_bindings/target/framework/DashSharedCore.xcframework'
##  s.public_header_files += '../../dash-shared-core-ferment/dash_spv_apple_bindings/target/framework/DashSharedCore.xcframework/**/*.h'
##s.public_header_files = '../../dash-shared-core-ferment/dash_spv_apple_bindings/target/framework/DashSharedCore.xcframework/**/*.h'
#
#end
#
