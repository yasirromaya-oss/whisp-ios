import SwiftUI

/// A ViewModifier that wraps content in a glassmorphic bento-box card
/// with material background, inner border, and soft shadow.
public struct GlassCard: ViewModifier {
    let cornerRadius: CGFloat
    let isGlowing: Bool
    let material: Material

    public init(
        cornerRadius: CGFloat = Theme.Radius.card,
        isGlowing: Bool = false,
        material: Material = .thinMaterial
    ) {
        self.cornerRadius = cornerRadius
        self.isGlowing = isGlowing
        self.material = material
    }

    public func body(content: Content) -> some View {
        content
            .background(material, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.Colors.innerBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
            .shadow(
                color: isGlowing ? Theme.Colors.subtleGlow : .clear,
                radius: isGlowing ? 16 : 0,
                x: 0,
                y: 2
            )
    }
}

// MARK: - View Extension

extension View {
    /// Applies the glassmorphic bento-box card style.
    public func glassCard(
        cornerRadius: CGFloat = Theme.Radius.card,
        isGlowing: Bool = false,
        material: Material = .thinMaterial
    ) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, isGlowing: isGlowing, material: material))
    }
}
