import SwiftUI

struct WhispLayout {
    let size: CGSize
    let headlineFontSize: CGFloat
    let headlineTopPadding: CGFloat
    let headlineHorizontalPadding: CGFloat
    let imageInsets: EdgeInsets
    let imageCornerRadius: CGFloat
}

// MARK: - Per-Device Constants

extension WhispLayout {

    /// iPhone 17 Pro Max — 6.9" (mandatory for App Store Connect)
    static let iPhone17ProMax = WhispLayout(
        size: CGSize(width: 1320, height: 2868),
        headlineFontSize: 88,
        headlineTopPadding: 260,
        headlineHorizontalPadding: 140,
        imageInsets: EdgeInsets(top: 24, leading: 100, bottom: 110, trailing: 100),
        imageCornerRadius: 32
    )

    /// iPhone 17 Pro — 6.3"
    static let iPhone17Pro = WhispLayout(
        size: CGSize(width: 1206, height: 2622),
        headlineFontSize: 80,
        headlineTopPadding: 240,
        headlineHorizontalPadding: 128,
        imageInsets: EdgeInsets(top: 20, leading: 92, bottom: 100, trailing: 92),
        imageCornerRadius: 30
    )

    /// iPhone 16e — 6.1" (smallest iPhone on iOS 26)
    static let iPhone16e = WhispLayout(
        size: CGSize(width: 1170, height: 2532),
        headlineFontSize: 76,
        headlineTopPadding: 228,
        headlineHorizontalPadding: 120,
        imageInsets: EdgeInsets(top: 20, leading: 88, bottom: 96, trailing: 88),
        imageCornerRadius: 28
    )

    /// iPad Pro 13" M5 (mandatory for App Store Connect)
    static let iPadPro13M5 = WhispLayout(
        size: CGSize(width: 2064, height: 2752),
        headlineFontSize: 100,
        headlineTopPadding: 240,
        headlineHorizontalPadding: 200,
        imageInsets: EdgeInsets(top: 24, leading: 140, bottom: 120, trailing: 140),
        imageCornerRadius: 36
    )

    /// Maps fastlane simulator device names to layouts.
    static let deviceNameMap: [String: WhispLayout] = [
        "iPhone 17 Pro Max": .iPhone17ProMax,
        "iPhone 17 Pro": .iPhone17Pro,
        "iPhone 16e": .iPhone16e,
        "iPad Pro 13-inch (M5)": .iPadPro13M5,
    ]
}
