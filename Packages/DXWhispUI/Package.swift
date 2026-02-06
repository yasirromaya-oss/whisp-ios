// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DXWhispUI",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
    ],
    products: [
        .library(name: "DXWhispUI", targets: ["DXWhispUI"]),
    ],
    dependencies: [
        .package(path: "../DXWhispKit"),
    ],
    targets: [
        .target(
            name: "DXWhispUI",
            dependencies: [
                "DXWhispKit",
            ],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
