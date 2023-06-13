#
# Be sure to run `pod lib lint YDRouter.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'YDRouter'
  s.version          = '0.1.5'
  s.summary          = '二次封装MGJRouter的路由库'

  s.homepage         = 'https://github.com/chong2vv/YDRouter'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'wangyuandong' => 'chong2vv@163.com' }
  s.source           = { :git => 'https://github.com/chong2vv/YDRouter.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'

  s.source_files = 'YDRouter/Classes/**/*'

end
