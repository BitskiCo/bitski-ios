Pod::Spec.new do |s|
  s.name             = 'Bitski'
  s.version          = '0.4.1'
  s.summary          = 'Bitski SDK for iOS. Interact with Ethereum wallets using simple OpenID auth.'

  s.description      = <<-DESC
  Provides tools for connecting to Ethereum wallets,
  creating transactions, and interacting with the Ethereum
  network through Web3.swift and OpenID Connect.
                       DESC

  s.homepage         = 'https://github.com/BitskiCo/bitski-ios'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Josh Pyles' => 'josh@outtherelabs.com' }
  s.source           = { :git => 'https://github.com/BitskiCo/bitski-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '11.0'
  s.swift_version = '4.0'

  s.source_files = 'Bitski/Classes/**/*'
  s.exclude_files = 'docs/**/*'

  s.dependency 'Web3', '~> 0.3.0'
  s.dependency 'Web3/ContractABI', '~> 0.3.0'
  s.dependency 'Web3/PromiseKit', '~> 0.3.0'
  s.dependency 'AppAuth', '~> 0.93'
  s.dependency 'BigInt.swift', '~> 1.0'
  s.dependency 'secp256k1.swift', '~> 0.1'
  s.dependency 'PromiseKit/CorePromise', '~> 6.0'

end
