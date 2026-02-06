import Foundation

/// A discovered screenshot with its parsed metadata.
struct DiscoveredScreenshot {
    let filePath: String
    let fileName: String
    let deviceName: String
    let screenName: String
}

enum ScreenshotDiscovery {

    /// Discovers screenshot PNGs in `directory`.
    ///
    /// Expected format: `{Device}-{Index}_{ScreenName}.png`
    /// e.g. `iPhone 17 Pro Max-01_NotesList.png`
    static func discover(in directory: String) throws -> [DiscoveredScreenshot] {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(atPath: directory)

        // Greedy first group captures the full device name (even with hyphens like "iPad Pro 13-inch (M5)")
        let pattern = #/^(.+)-(\d{2})_(.+)\.png$/#

        var results: [DiscoveredScreenshot] = []

        for fileName in contents.sorted() {
            guard let match = fileName.wholeMatch(of: pattern) else { continue }

            let deviceName = String(match.1)
            let screenName = String(match.3)
            let filePath = (directory as NSString).appendingPathComponent(fileName)

            results.append(DiscoveredScreenshot(
                filePath: filePath,
                fileName: fileName,
                deviceName: deviceName,
                screenName: screenName
            ))
        }

        return results
    }
}
