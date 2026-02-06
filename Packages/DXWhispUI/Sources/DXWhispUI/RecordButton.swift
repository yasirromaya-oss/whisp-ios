import DXWhispKit
import SwiftUI

public struct RecordButton: View, Equatable {
    let state: RecordingState
    let action: () -> Void

    @SwiftUI.State private var isPulsing = false

    public init(state: RecordingState, action: @escaping () -> Void) {
        self.state = state
        self.action = action
    }

    nonisolated public static func == (lhs: RecordButton, rhs: RecordButton) -> Bool {
        lhs.state == rhs.state
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                // Outer glow ring — faint at idle, active when recording
                Circle()
                    .stroke(Theme.Colors.accentGradient, lineWidth: 2)
                    .frame(width: 100, height: 100)
                    .shadow(color: Theme.Colors.subtleGlow, radius: isPulsing ? 20 : 8, x: 0, y: 0)
                    .opacity(isRecording ? (isPulsing ? 0.6 : 1.0) : 0.2)

                // Main button
                Circle()
                    .fill(buttonFill)
                    .frame(width: 88, height: 88)
                    .shadow(color: isRecording ? Theme.Colors.subtleGlow : .black.opacity(0.12), radius: 12, x: 0, y: 4)
                    .scaleEffect(scaleEffect)

                if case .processing = state {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Theme.Colors.accent)
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: imageName)
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: state)
        .onChange(of: isRecording) { _, recording in
            if recording {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            } else {
                isPulsing = false
            }
        }
    }

    private var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    private var buttonFill: some ShapeStyle {
        if case .processing = state {
            return AnyShapeStyle(.thinMaterial)
        }
        return AnyShapeStyle(Theme.Colors.accentGradient)
    }

    private var scaleEffect: CGFloat {
        if case .recording = state { return 1.08 }
        return 1.0
    }

    private var imageName: String {
        switch state {
        case .idle:
            "mic.fill"
        case .recording:
            "stop.fill"
        case .processing:
            "mic.fill"
        }
    }

    private var isDisabled: Bool {
        if case .processing = state { return true }
        return false
    }
}

#Preview("Idle") {
    RecordButton(state: .idle, action: {})
}

#Preview("Recording") {
    RecordButton(state: .recording(duration: 12.5), action: {})
}

#Preview("Processing") {
    RecordButton(state: .processing, action: {})
}
