import SwiftUI

// MARK: - Level Smoother

/// Frame-rate-independent exponential smoother for audio levels.
/// Reference type so it persists across TimelineView redraws without
/// triggering SwiftUI state invalidation.
private final class LevelSmoother {
    private var current: CGFloat = 0
    private var lastTime: TimeInterval = 0

    /// Smooths toward `target` using time-based exponential decay.
    /// Returns the interpolated value for the current frame.
    func smooth(toward target: CGFloat, at time: TimeInterval) -> CGFloat {
        if lastTime == 0 {
            lastTime = time
            current = target
            return current
        }
        let elapsed = min(time - lastTime, 0.05)
        lastTime = time

        // Asymmetric response: fast attack, gentle release
        let speed: CGFloat = target > current ? 12 : 6
        let factor = 1 - exp(-speed * elapsed)
        current += (target - current) * factor
        return current
    }
}

// MARK: - SoundWaveView

/// A reactive sound-wave visualizer driven by live audio levels.
///
/// Renders a row of capsule bars whose heights respond to `audioLevel`.
/// Each bar has a slight phase offset creating a flowing wave effect.
/// When idle (`audioLevel ≈ 0`), bars settle to a minimal ambient pulse.
/// Uses time-based exponential smoothing for buttery 60/120fps transitions.
public struct SoundWaveView: View {
    /// Normalized audio power in 0.0…1.0.
    let audioLevel: Float

    private let barCount = 48
    private let barWidth: CGFloat = 2.5
    private let minBarHeight: CGFloat = 2

    @State private var smoother = LevelSmoother()

    public init(audioLevel: Float) {
        self.audioLevel = audioLevel
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let level = smoother.smooth(
                toward: CGFloat(audioLevel),
                at: time
            )

            Canvas { context, size in
                drawBars(in: context, size: size, time: time, level: level)
            }
        }
    }

    private func drawBars(
        in context: GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        level: CGFloat
    ) {
        let gap = (size.width - barWidth * CGFloat(barCount)) / CGFloat(max(barCount - 1, 1))
        let step = barWidth + gap
        let centerX = size.width / 2
        let centerY = size.height / 2
        let halfH = size.height / 2

        for i in 0..<barCount {
            let x = CGFloat(i) * step
            let barMidX = x + barWidth / 2

            // Gaussian envelope — taller at center, tapers to edges
            let norm = abs(barMidX - centerX) / centerX
            let envelope = exp(-norm * norm * 3.0)

            // Multi-frequency wave for organic motion
            let p = Double(i) * 0.22
            let w1 = sin(time * 2.4 + p) * 0.25
            let w2 = sin(time * 4.1 + p * 1.3) * 0.12
            let w3 = sin(time * 1.3 + p * 0.7) * 0.08
            let wave = CGFloat(w1 + w2 + w3)

            // Bar height: smooth blend between idle breathing and active response
            let active = halfH * envelope * (0.25 + level * 0.75 + wave * (0.15 + level * 0.35))
            let idle   = halfH * envelope * 0.045 * (1.0 + wave * 0.6)
            let blend  = min(level / 0.05, 1.0)   // gradual crossfade over 0…0.05
            let h = max(minBarHeight, idle + (active - idle) * blend)

            // Symmetric bar from center
            let rect = CGRect(x: x, y: centerY - h, width: barWidth, height: h * 2)
            let path = Capsule().path(in: rect)

            // Gradient intensity — brighter bars at higher amplitude
            let intensity = min(h / halfH, 1.0)
            let alpha = 0.35 + Double(intensity) * 0.65

            // Subtle per-bar glow at high levels
            if intensity > 0.3 {
                var glowCtx = context
                glowCtx.opacity = Double(intensity) * 0.3
                glowCtx.addFilter(.blur(radius: 6))
                glowCtx.fill(path, with: .color(accentColor(intensity: intensity, alpha: 1)))
            }

            context.fill(path, with: .color(accentColor(intensity: intensity, alpha: alpha)))
        }
    }

    private func accentColor(intensity: CGFloat, alpha: Double) -> Color {
        Color(
            red: 0.345 + Double(intensity) * 0.15,
            green: 0.345 + Double(intensity) * 0.15,
            blue: 0.996
        ).opacity(alpha)
    }
}

// MARK: - Legacy API Wrapper

/// Drop-in replacement for the previous Lottie-based animation.
/// Now delegates to `SoundWaveView` with audio-reactive bars.
public struct RecordingAnimationView: View {
    let isAnimating: Bool
    var audioLevel: Float

    public init(isAnimating: Bool, audioLevel: Float = 0) {
        self.isAnimating = isAnimating
        self.audioLevel = audioLevel
    }

    public var body: some View {
        SoundWaveView(audioLevel: isAnimating ? audioLevel : 0)
    }
}

#Preview("Idle") {
    SoundWaveView(audioLevel: 0)
        .frame(width: 340, height: 160)
        .padding()
        .background(.black)
}

#Preview("Low Level") {
    SoundWaveView(audioLevel: 0.2)
        .frame(width: 340, height: 160)
        .padding()
        .background(.black)
}

#Preview("Medium Level") {
    SoundWaveView(audioLevel: 0.5)
        .frame(width: 340, height: 160)
        .padding()
        .background(.black)
}

#Preview("High Level") {
    SoundWaveView(audioLevel: 0.85)
        .frame(width: 340, height: 160)
        .padding()
        .background(.black)
}
