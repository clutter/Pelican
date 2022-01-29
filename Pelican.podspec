Pod::Spec.new do |s|
  s.name             = 'Pelican'
  s.version          = '2.0.0'
  s.platform     = :ios, "12.0"
  s.swift_versions   = ['5.0']
  s.summary          = 'Batch processing library written in Swift'

  s.description      = <<-DESC
Pelican is a persisted batching library useful for log rolling, event logging or doing other periodic background processing.
                       DESC

  s.homepage         = 'https://github.com/clutter/Pelican'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'bd755bf4f7e672000cab58c4b721a8cdbe22a839' => 'robmanson@gmail.com' }
  s.source           = { :git => 'https://github.com/clutter/Pelican.git', :tag => s.version.to_s }

  s.source_files = 'Pelican/Lib/**/*'

  s.test_spec 'Tests' do |test_spec|
    test_spec.requires_app_host = false
    test_spec.source_files = 'Tests/PelicanTests/*.swift'
  end
end
