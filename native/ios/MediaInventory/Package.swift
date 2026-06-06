// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MediaInventory",
    platforms: [.iOS(.v18)],
    dependencies: [
        .package(url: "https://github.com/hotwired/hotwire-native-ios", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "MediaInventory",
            dependencies: [
                .product(name: "HotwireNative", package: "hotwire-native-ios")
            ],
            path: "Sources"
        )
    ]
)
