# Bitski iOS SDK

[![CocoaPods](https://img.shields.io/cocoapods/v/Bitski.svg?style=flat)](https://cocoapods.org/pods/Bitski)
[![CocoaPods](https://img.shields.io/cocoapods/l/Bitski.svg?style=flat)](https://github.com/BitskiCo/bitski-ios/blob/master/LICENSE)
[![CocoaPods](https://img.shields.io/cocoapods/p/Bitski.svg?style=flat)](https://github.com/BitskiCo/bitski-ios)
[![Documentation](https://bitskico.github.io/bitski-ios/badge.svg)](https://bitskico.github.io/bitski-ios/)
[![Codecov](https://img.shields.io/codecov/c/github/bitskico/bitski-ios.svg?style=flat)](https://codecov.io/gh/bitskico/bitski-ios)

The official [Bitski](https://www.bitski.com) SDK for iOS. Build decentralized iOS apps with Ethereum with OAuth-based cross-platform wallet.

- Read our [Documentation](https://docs.bitski.com) or the [API Reference](https://bitskico.github.io/bitski-ios/) to get started.
- Want to see an example of the SDK in action? Check out our [iOS Example Dapp](https://github.com/BitskiCo/example-native-dapp).
- Learn more about what's possible with Ethereum on iOS at [Web3.swift](https://github.com/Boilertalk/Web3.swift).

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first. You'll need to add your client id and redirect url to `AppDelegate`.

## Requirements

- Currently only supports iOS 11 and above

## Installation

Bitski is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'Bitski'
```

## Usage


### Initialization

First, get a client ID by creating an app [here](https://developer.bitski.com). Make sure you select 'Native App' for App Type.

You'll also need to add the `redirectURL` you use in the app under Redirect URLs in the developer portal. This ensures that only urls that you trust can be used with your client id.

In your app, you'll initialize an instance of Bitski:

```swift
// Replace redirect URL with an url scheme that will hit your native app
Bitski.shared = Bitski(clientID: "<YOUR CLIENT ID>", redirectURL: URL(string: "exampleapp://application/callback")!)
```
We provide a convenient static place to initialize your instance in `Bitski.shared`, but if you want to avoid using a singleton you can store your instance however
works best for you.

### Authentication

Once you have an instance of `Bitski` configured, you can check the signed in status. The user will need to be logged in before making any Web3 calls.

```swift
if Bitski.shared?.isLoggedIn == true {
    self.web3 = Bitski.shared?.getWeb3()
    // show logged in state
} else {
    // show logged out state
}
```

To sign in, simply call `signIn()` (this will open a browser window):

```swift
Bitski.shared?.signIn() { error in
    // Once signed in, get an instance of Web3
    self.web3 = Bitski.shared?.getWeb3()
    // or, specify a network with getWeb3(network:)
}
```

A user will remain signed in indefinitely, unless the access token is revoked. To explicitly sign out:

```swift
Bitski.shared?.signOut()
```

### Local Dev

If you're developing locally (like with truffle develop or ganache), you can use the development network instead.

```swift
let network: Bitski.Network = .development(url: "http://localhost:9545", chainId: 0) //or use your local IP if building for a device.
let web3 = Bitski.getWeb3(network: network)
```

### Handling Implicit Logouts

Notifications will be posted when the user is signed in and signed out (`Bitski.LoggedInNotification` and `Bitski.LoggedOutNotification`) respectively.
A user can be signed out either explicitly, or implicitly if the access token is revoked. Therefore, it's a good practice to respond to these notifications.

```swift
NotificationCenter.default.addObserver(self, selector: #selector(userDidLogout), name: Bitski.LoggedOutNotification, object: nil)
```

### Using Web3

Once you have an instance of Web3 intialized, you can use it to make Ethereum calls and transactions. We provide full access to the Ethereum network through
our API.

```swift
// Example: Make a simple transfer transaction
firstly {
    web3.eth.accounts().firstValue
}.then { account in
    let to = try? EthereumAddress(hex: "SOME ADDRESS", eip55: false)
    let transaction = EthereumTransaction(nonce: nil, gasPrice: EthereumQuantity(quantity: 1.gwei), gas: EthereumQuantity(quantity: 21.gwei), from: account, to: to, value: EthereumQuantity(quantity: 1.eth))
    return web3.eth.sendTransaction(transaction: transaction)
}.then { transactionHash in
    web3.eth.getTransactionReceipt(transactionHash)
}.done { receipt in
    let watcher = TransactionWatcher(hash: transactionHash, web3: web3)
    watcher.expectedConfirmations = 3
    watcher.delegate = self
    self.transactionWatcher = watcher
}
```

For more about what you can do in Web3, see [Web3.swift](https://github.com/Boilertalk/Web3.swift).

### Authorization

Our Web3 provider lets you send transactions to be signed, but the user must explictly approve them. For security, this authorization happens in our web UI
and will display as a browser modal above your application. Once the transaction has been approved or rejected, the modal will dismiss.
For the best experience we recommend limiting the amount of transactions you send.

## Report Vulnerabilities
Bitski provides a “bug bounty” to engage with the security researchers in the community. If you have found a vulnerability in our product or service, please [submit a vulnerability report](https://www.bitski.com/bounty) to the Bitski security team.

## License

Bitski is available under the MIT license. See the LICENSE file for more info.
