// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MediaInventory",
    platforms: [.iOS("18.0")],
    dependencies: [
        .package(url: "https://github.com/hotwired/hotwire-native-ios", from: "1.3.1")
    ],
    targets: [
        .target(
            name: "MediaInventory",
            dependencies: [
                .product(name: "HotwireNative", package: "hotwire-native-ios")
            ],
            path: "Sources",
            exclude: ["Resources/Info.plist"],
            resources: [.copy("Configuration/path-configuration.json")]
        )
    ]
)
