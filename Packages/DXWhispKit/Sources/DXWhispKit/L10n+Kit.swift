import Foundation

// MARK: - L10nKit — Localization Keys (DXWhispKit Package)

public enum L10nKit {
    static func speaker(_ number: Int) -> String {
        String(localized: "Speaker \(number)", bundle: .module)
    }

    static let errorUnauthorized = String(localized: "kit_error_unauthorized", defaultValue: "Speech recognition permission needed. Please allow access when prompted.", bundle: .module)
    static let errorDenied = String(localized: "kit_error_denied", defaultValue: "Speech recognition denied. Enable it in Settings → DXWhisp.", bundle: .module)
    static let errorRestricted = String(localized: "kit_error_restricted", defaultValue: "Speech recognition restricted on this device.", bundle: .module)
    static let errorUnavailable = String(localized: "kit_error_unavailable", defaultValue: "Transcription unavailable. Use a real iPhone or iPad.", bundle: .module)
    static let errorNoResult = String(localized: "kit_error_no_result", defaultValue: "No transcription result. Try speaking more clearly.", bundle: .module)
}
