import ComposableArchitecture
import DXWhispKit
import SwiftUI

@main
struct DXWhispApp: App {
    static let store: StoreOf<RootFeature> = {
        #if DEBUG
        if CommandLine.arguments.contains("-screenshotMode") {
            return Store(initialState: RootFeature.State()) {
                RootFeature()
            } withDependencies: {
                $0.persistence = .screenshotValue
                $0.audioRecorder = .screenshotValue
            }
        }
        #endif
        return Store(initialState: RootFeature.State()) {
            RootFeature()
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView(store: Self.store)
                .modifier(ScreenshotAppearanceModifier())
        }
    }
}

// MARK: - Screenshot Appearance

/// Applies `.preferredColorScheme` based on `-lightMode` / `-darkMode` launch arguments.
private struct ScreenshotAppearanceModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if DEBUG
        if CommandLine.arguments.contains("-darkMode") {
            content.preferredColorScheme(.dark)
        } else if CommandLine.arguments.contains("-lightMode") {
            content.preferredColorScheme(.light)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
