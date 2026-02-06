// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DXWhispKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
    ],
    products: [
        .library(name: "DXWhispKit", targets: ["DXWhispKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.6.0"),
    ],
    targets: [
        .target(
            name: "DXWhispKit",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
