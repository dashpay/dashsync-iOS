#
# Be sure to run `pod lib lint DashSyncPod.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'DashSync'
  s.version          = '0.9.0'
  s.summary          = 'Dash Sync is a light and configurable blockchain client that you can embed into your iOS Application.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = 'Dash Sync is a light blockchain client that you can embed into your iOS Application.  It is fully customizable to make the type of node you are interested in.'

  s.homepage         = 'https://github.com/dashevo/dashsync'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'quantumexplorer' => 'quantum@dash.org' }
  s.source           = { :git => 'https://github.com/quantumexplorer/dashsync.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'

  s.source_files = "dashsync/**/*.{h,m}"
  
  # s.resource_bundles = {
  #   'DashSyncPod' => ['DashSyncPod/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'UIKit', 'Security'
  s.libraries = 'bz2', 'sqlite3'
  # s.dependency 'AFNetworking', '~> 2.3'
end

