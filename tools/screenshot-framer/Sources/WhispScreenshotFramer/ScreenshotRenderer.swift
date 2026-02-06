import AppKit
import SwiftUI

/// Renders a SwiftUI view to a PNG file at 1:1 point-to-pixel scale.
/// Inlined from FrameKit to avoid dependency conflicts.
struct ScreenshotRenderer {

    enum Error: Swift.Error, CustomStringConvertible {
        case renderFailed(String)
        case saveFailed(String)

        var description: String {
            switch self {
            case .renderFailed(let msg): return msg
            case .saveFailed(let msg): return msg
            }
        }
    }

    let outputPath: String
    let imageFormat: NSBitmapImageRep.FileType

    func render<V: View>(_ view: V, size: CGSize) throws {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(origin: .zero, size: size)
        hosting.layer?.contentsScale = 1.0

        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.frame) else {
            throw Error.renderFailed("Could not create bitmap for view")
        }
        bitmap.pixelsWide = Int(size.width)
        bitmap.pixelsHigh = Int(size.height)
        bitmap.size = size
        hosting.cacheDisplay(in: hosting.frame, to: bitmap)

        guard let data = bitmap.representation(using: imageFormat, properties: [:]) else {
            throw Error.renderFailed("Could not encode bitmap to image data")
        }

        guard FileManager.default.createFile(atPath: outputPath, contents: data) else {
            throw Error.saveFailed("Could not write image to \(outputPath)")
        }
    }
}
