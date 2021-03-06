#
# Be sure to run `pod lib lint Pelican.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Pelican'
  s.version          = '2.0.0'
  s.swift_versions   = ['5.0']
  s.summary          = 'Batch processing library written in Swift'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Pelican is a persisted batching library useful for log rolling, event logging or doing other periodic background processing.
                       DESC

  s.homepage         = 'https://github.com/clutter/Pelican'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'bd755bf4f7e672000cab58c4b721a8cdbe22a839' => 'robmanson@gmail.com' }
  s.source           = { :git => 'https://github.com/clutter/Pelican.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'Pelican/Lib/**/*'
  
  # s.resource_bundles = {
  #   'Pelican' => ['Pelican/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
