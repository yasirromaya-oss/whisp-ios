import SwiftUI

/// Central design-token namespace for the Luxe Minimalist design system.
public enum Theme {

    // MARK: - Colors

    public enum Colors {
        public static var innerBorder: Color {
            Color.white.opacity(0.12)
        }

        public static var innerBorderDark: Color {
            Color.white.opacity(0.08)
        }

        public static var subtleGlow: Color {
            Color(red: 0.345, green: 0.345, blue: 0.996).opacity(0.35)
        }

        public static var textPrimary: Color { .primary }
        public static var textSecondary: Color { .secondary }
        public static var textTertiary: Color { Color.secondary.opacity(0.6) }

        public static var accent: Color {
            Color(red: 0.345, green: 0.345, blue: 0.996)
        }

        public static var accentGradient: LinearGradient {
            LinearGradient(
                colors: [
                    Color(red: 0.345, green: 0.345, blue: 0.996),
                    Color(red: 0.478, green: 0.478, blue: 0.996),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Corner Radii

    public enum Radius {
        public static let card: CGFloat = 20
        public static let section: CGFloat = 16
        public static let button: CGFloat = 12
    }

    // MARK: - Spacing (8pt grid)

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 24
        public static let xxxl: CGFloat = 32
    }

    // MARK: - Shadows

    public enum Shadow {
        public static func glow(_ color: Color = Colors.subtleGlow) -> some ViewModifier {
            ShadowModifier(color: color, radius: 16, x: 0, y: 2)
        }
    }

    // MARK: - Typography

    public enum Typography {
        public static var display: Font { .system(size: 56, weight: .ultraLight, design: .monospaced) }
        public static var title: Font { .system(size: 28, weight: .semibold) }
        public static var headline: Font { .system(size: 17, weight: .semibold) }
        public static var body: Font { .system(size: 15, weight: .regular) }
        public static var caption: Font { .system(size: 12, weight: .medium) }
        public static var mono: Font { .system(size: 13, weight: .regular, design: .monospaced) }
    }
}

// MARK: - Shadow Modifier

private struct ShadowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color, radius: radius, x: x, y: y)
    }
}
