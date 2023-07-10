// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Bitski-iOS-SDK",
    platforms: [
        .iOS(.v16),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "Bitski-iOS-SDK",
            targets: ["Bitski-iOS-SDK"]),
    ],
    dependencies: [
        .package(url: "https://github.com/openid/AppAuth-iOS.git", from: "1.6.0"),
        .package(url: "https://github.com/BitskiCo/Web3.swift", from: "0.5.6"),
        .package(url: "https://github.com/mxcl/PromiseKit.git", from: "6.0.0"),
        .package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", from: "1.9.5"),
        .package(url: "https://github.com/OutThereLabs/opentelemetry-swift", branch: "otlphttp"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Bitski-iOS-SDK",
            dependencies: [
                .product(name: "AppAuth", package: "AppAuth-iOS"),
                .product(name: "Web3", package: "Web3.swift"),
                .product(name: "Web3PromiseKit", package: "Web3.swift"),
                .product(name: "Web3ContractABI", package: "Web3.swift"),
                .product(name: "PromiseKit", package: "PromiseKit"),
                .product(name: "SwiftyBeaver", package: "SwiftyBeaver"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
            ],
            path: "./Bitski/Classes"),
    ]
)
