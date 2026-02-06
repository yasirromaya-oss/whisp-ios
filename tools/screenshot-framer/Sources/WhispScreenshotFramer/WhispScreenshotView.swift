import AppKit
import SwiftUI

// MARK: - Brand Colors

private enum Brand {
    static let accent = Color(red: 0.345, green: 0.345, blue: 0.996)
    static let accentEnd = Color(red: 0.478, green: 0.478, blue: 0.996)
    static let base = Color(red: 0.02, green: 0.02, blue: 0.04)
}

// MARK: - View

struct WhispScreenshotView: View {
    let layout: WhispLayout
    let content: WhispContent

    var body: some View {
        ZStack {
            background
            foreground
        }
        .frame(width: layout.size.width, height: layout.size.height)
    }

    // MARK: - Background Layers

    private var background: some View {
        ZStack {
            // Base: near-black
            Brand.base

            // Primary glow: large periwinkle orb behind the screenshot
            RadialGradient(
                colors: [
                    Brand.accent.opacity(0.28),
                    Brand.accent.opacity(0.08),
                    Color.clear,
                ],
                center: .init(x: 0.5, y: 0.62),
                startRadius: 0,
                endRadius: layout.size.width * 0.75
            )

            // Top accent glow: subtle halo behind headline
            RadialGradient(
                colors: [
                    Brand.accentEnd.opacity(0.10),
                    Color.clear,
                ],
                center: .init(x: 0.5, y: 0.12),
                startRadius: 0,
                endRadius: layout.size.width * 0.45
            )

            // Bottom edge bleed
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.65),
                    .init(color: Brand.accent.opacity(0.12), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Foreground Content

    private var foreground: some View {
        VStack(spacing: 0) {
            headline
            Spacer()
            screenshot
        }
    }

    // MARK: - Headline

    private var headline: some View {
        Text(content.headline)
            .font(.system(size: layout.headlineFontSize, weight: .bold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            // Subtle text glow
            .shadow(color: Brand.accent.opacity(0.6), radius: 24, x: 0, y: 0)
            .shadow(color: .white.opacity(0.15), radius: 4, x: 0, y: 0)
            .padding(.top, layout.headlineTopPadding)
            .padding(.horizontal, layout.headlineHorizontalPadding)
    }

    // MARK: - Screenshot

    private var screenshot: some View {
        Image(nsImage: content.screenshotImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: layout.imageCornerRadius, style: .continuous))
            // Glass-card inner border
            .overlay(
                RoundedRectangle(cornerRadius: layout.imageCornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.30),
                                Color.white.opacity(0.08),
                                Brand.accent.opacity(0.25),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            // Layered shadows for depth
            .shadow(color: Brand.accent.opacity(0.50), radius: 40, x: 0, y: 12)
            .shadow(color: Brand.accent.opacity(0.25), radius: 80, x: 0, y: 24)
            .shadow(color: Color.black.opacity(0.60), radius: 20, x: 0, y: 10)
            .padding(layout.imageInsets)
    }
}
