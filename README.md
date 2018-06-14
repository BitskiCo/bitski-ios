# Bitski

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first. You'll need to add your client id and redirect url to `AppDelegate`.

## Requirements

- Currently supports iOS 11 only

## Installation

Bitski is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'Bitski'
```

## Usage


### Initialization

First, request a client ID by signing up [here](https://developer.bitski.com). Make sure you request an offline scope so that your access tokens can be refreshed.
You'll also need to associate the redirectURL you use with your client id in the developer portal. This ensures that only urls that you trust can be used with your client id.

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
    self.web3 = Bitski.shared?.getWeb3(network: .kovan)
    // show logged in state
} else {
    // show logged out state
}
```

To sign in, simply call `signIn()` (this will open a browser window):

```swift
Bitski.shared?.signIn() { error in
    // Once signed in, get an instance of Web3 for the network you want
    // Currently we only support kovan and rinkeby. mainnet coming soon.
    self.web3 = Bitski.shared?.getWeb3(network: .kovan)
}
```

A user will remain signed in indefinitely, unless the access token is revoked. To explicitly sign out:

```swift
Bitski.shared?.signOut()
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
    web3.eth.accounts()
}.then { accounts in
    guard let account = accounts.first else { throw SomeError }
    let to = EthereumAddress(hex: "SOME ADDRESS", eip55: false)
    let transaction = EthereumTransaction(gasLimit: 21000, from: account, to: to, value: EthereumQuantity(quantity: 1.eth))
    return web3.eth.sendTransaction(transaction: transaction)
}.then { transactionHash in
    web3.eth.getTransactionReceipt(transactionHash)
}.done { receipt in
    // Retrieved the receipt!
}
```

For more about what you can do in Web3, see [Web3.swift](https://github.com/Boilertalk/Web3.swift).

### Authorization

Our Web3 provider lets you send transactions to be signed, but the user must explictly approve them. For security, this authorization happens in our web UI 
and will display as a browser modal above your application. Once the transaction has been approved or rejected, the modal will dismiss. 
For the best experience we recommend limiting the amount of transactions you send.

## License

Bitski is available under the MIT license. See the LICENSE file for more info.
