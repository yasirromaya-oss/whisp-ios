/// Maps screenshot screen-name suffixes to marketing headlines.
enum HeadlineConfig {
    static let headlines: [String: String] = [
        "NotesList": "Your Voice, Organized",
        "NoteDetail_Insights": "AI-Powered Insights",
        "NoteDetail_ActionItems": "Never Miss an Action Item",
        "Recording": "Record with One Tap",
        "Settings": "Your Way, Your Workflow",
    ]

    /// Returns the headline for a screen name, or a fallback derived from the name.
    static func headline(for screenName: String) -> String {
        headlines[screenName] ?? screenName
            .replacingOccurrences(of: "_", with: " ")
    }
}
