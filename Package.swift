// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MQTT-Client",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "MQTTClient",
            targets: ["MQTTClient"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/qustodio/SocketRocket", branch: "93ddadda6a56f0ddd199182c14c9dc4b16026028"),
        //.package(url: "https://github.com/getsentry/sentry-cocoa", exact: "7.31.2"),
        //.package(url: "https://github.com/firebase/firebase-ios-sdk.git", exact: "10.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "MQTTClient",
            dependencies: [
                "SocketRocket"
               // .product(name: "CocoaMQTTWebSocket", package: "CocoaMQTT")
            ],
            path: "MQTTClient/MQTTClient"
        )
        /*.testTarget(
            name: "MQTTTests",
            dependencies: ["MQTT"],
            path: "Targets/MQTT/Tests"
        ),*/
    ]
)
