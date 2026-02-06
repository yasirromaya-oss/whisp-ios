import SwiftUI

/// A full-screen overlay that shows an error message to the end user.
public struct ErrorOverlay: View, Equatable {
    let title: String
    let message: String
    let dismiss: () -> Void

    @SwiftUI.State private var appeared = false

    public init(title: String, message: String, dismiss: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.dismiss = dismiss
    }

    nonisolated public static func == (lhs: ErrorOverlay, rhs: ErrorOverlay) -> Bool {
        lhs.title == rhs.title && lhs.message == rhs.message
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            VStack(spacing: Theme.Spacing.xl) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.red.opacity(0.8))

                Text(title)
                    .font(Theme.Typography.headline)

                Text(message)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: dismiss) {
                    Text(L10nUI.ok)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(Theme.Colors.accentGradient, in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                }
                .padding(.top, Theme.Spacing.sm)
            }
            .padding(Theme.Spacing.xxl)
            .frame(maxWidth: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(Theme.Colors.innerBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 8)
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    appeared = true
                }
            }
        }
    }
}

#Preview {
    ErrorOverlay(
        title: "Something went wrong",
        message: "Transcription isn't available here. Use a real iPhone or iPad — it doesn't work in the Simulator.",
        dismiss: {}
    )
}
