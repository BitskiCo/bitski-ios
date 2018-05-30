#
# Be sure to run `pod lib lint Bitski.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Bitski'
  s.version          = '0.1.3'
  s.summary          = 'Bitski SDK for iOS. Interact with Ethereum wallets using simple OpenID auth.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  Provides tools for connecting to Ethereum wallets,
  creating transactions, and interacting with the Ethereum
  network through Web3.swift and OpenID Connect.
                       DESC

  s.homepage         = 'https://github.com/BitskiCo/BitskiSDK'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Josh Pyles' => 'josh@outtherelabs.com' }
  s.source           = { :git => 'https://github.com/BitskiCo/BitskiSDK.git', :tag => s.version.to_s }

  s.ios.deployment_target = '11.0'
  s.swift_version = '4.0'
  
  s.source_files = 'Bitski/Classes/**/*'

  s.dependency 'Web3', '~> 0.1'
  s.dependency 'Web3/PromiseKit', '~> 0.1'
  s.dependency 'AppAuth', '~> 0.92'
  s.dependency 'BigInt.swift', '~> 1.0'
  s.dependency 'secp256k1.swift', '~> 0.1'
  s.dependency 'PromiseKit/CorePromise', '~> 6.0'
  
  # s.resource_bundles = {
  #   'Bitski' => ['Bitski/Assets/*.png']
  # }
  
  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
end
