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

  s.ios.deployment_target = '12.0'
  
  s.requires_arc = true

  s.source_files = "DashSync/**/*.{h,m,mm}"
  s.public_header_files = 'DashSync/**/*.h'
  s.private_header_files = 'DashSync/crypto/x11/*.h'
  s.libraries = 'bz2', 'sqlite3'
  s.resource_bundles = {'DashSync' => ['DashSync/*.xcdatamodeld', 'DashSync/MappingModels/*.xcmappingmodel', 'DashSync/*.plist', 'DashSync/*.lproj', 'DashSync/MasternodeLists/*.dat', 'DashSync/*.json']}
  
  s.framework = 'Foundation', 'UIKit', 'SystemConfiguration', 'CoreData', 'BackgroundTasks'
  s.compiler_flags = '-Wno-comma'
  s.dependency 'secp256k1_dash', '0.1.3-alpha.2'
  s.dependency 'bls-signatures-pod', '0.2.10'
  s.dependency 'CocoaLumberjack', '3.6.0'
  s.dependency 'DWAlertController', '0.2.1'
  s.dependency 'DSDynamicOptions', '0.1.1'
  s.dependency 'DAPI-GRPC', '0.0.1'
  s.dependency 'TinyCborObjc', '0.4.6'
  s.prefix_header_contents = '#import "DSEnvironment.h"'
  
end

