import AppKit
import ArgumentParser

@main
struct FrameCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "whisp-frame",
        abstract: "Frame DXWhisp App Store screenshots with branded backgrounds and headlines."
    )

    @Option(name: .long, help: "Directory containing raw screenshots from fastlane snapshot.")
    var inputDir: String = "./fastlane/screenshots/en-US"

    @Option(name: .long, help: "Directory to write framed screenshots. Defaults to input directory (overwrite in place).")
    var outputDir: String?

    mutating func run() throws {
        let inputPath = (inputDir as NSString).standardizingPath
        let outputPath = (outputDir.map { ($0 as NSString).standardizingPath }) ?? inputPath

        let fm = FileManager.default
        if !fm.fileExists(atPath: outputPath) {
            try fm.createDirectory(atPath: outputPath, withIntermediateDirectories: true)
        }

        let screenshots = try ScreenshotDiscovery.discover(in: inputPath)
        guard !screenshots.isEmpty else {
            print("No screenshots found in \(inputPath)")
            return
        }

        print("Found \(screenshots.count) screenshot(s) in \(inputPath)")

        var framed = 0
        var skipped = 0

        for screenshot in screenshots {
            guard let layout = WhispLayout.deviceNameMap[screenshot.deviceName] else {
                print("  SKIP \(screenshot.fileName) — unknown device \"\(screenshot.deviceName)\"")
                skipped += 1
                continue
            }

            guard let image = NSImage(contentsOfFile: screenshot.filePath) else {
                print("  SKIP \(screenshot.fileName) — could not load image")
                skipped += 1
                continue
            }

            let headline = HeadlineConfig.headline(for: screenshot.screenName)
            let content = WhispContent(headline: headline, screenshotImage: image)
            let view = WhispScreenshotView(layout: layout, content: content)

            let outputFile = (outputPath as NSString).appendingPathComponent(screenshot.fileName)
            let renderer = ScreenshotRenderer(outputPath: outputFile, imageFormat: .png)
            try renderer.render(view, size: layout.size)

            framed += 1
            print("  OK   \(screenshot.fileName) → \(headline)")
        }

        print("Done: \(framed) framed, \(skipped) skipped")
    }
}
