import ComposableArchitecture
import DXWhispKit
import DXWhispUI
import SwiftUI

public struct RecordingView: View {
    @SwiftUI.Bindable var store: StoreOf<RecordingFeature>

    public init(store: StoreOf<RecordingFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [.clear, Theme.Colors.accent.opacity(isRecording ? 0.06 : 0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if let postRecording = store.postRecording {
                postRecordingContent(postRecording)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                recordingContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isRecording)
        .animation(.easeInOut(duration: 0.3), value: store.postRecording != nil)
        .onAppear {
            store.send(.onAppear)
        }
        .overlay {
            if let message = store.error, store.postRecording == nil {
                ErrorOverlay(
                    title: L10n.Common.somethingWentWrong,
                    message: message,
                    dismiss: { store.send(.dismissError) }
                )
            }
        }
    }

    // MARK: - Recording UI

    @ViewBuilder
    private var recordingContent: some View {
        VStack(spacing: 0) {
            // Timer — top
            Text(formattedDuration)
                .font(Theme.Typography.display)
                .foregroundStyle(isRecording ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.xxxl)

            Spacer(minLength: Theme.Spacing.xl)

            // Sound wave animation
            if isRecording {
                SoundWaveView(audioLevel: store.audioLevel)
                    .frame(height: 160)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .center)))
            }

            Spacer(minLength: Theme.Spacing.md)

            // Record button — bottom
            VStack(spacing: Theme.Spacing.sm) {
                RecordButton(state: store.recordingState) {
                    store.send(.recordButtonTapped)
                }
                .accessibilityIdentifier("record_button")

                Text(helperText)
                    .font(.footnote.weight(.regular))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .padding(.top, Theme.Spacing.xs)
            }
            .padding(.bottom, Theme.Spacing.xxxl)
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    // MARK: - Post-Recording UI

    @ViewBuilder
    private func postRecordingContent(
        _ postRecording: RecordingFeature.PostRecordingState
    ) -> some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            switch postRecording {
            case .transcribing:
                transcribingContent

            case .completed(let note):
                completedContent(note)

            case .failed(let message):
                failedContent(message)
            }

            Spacer()

            if case .transcribing = postRecording {
                // No button while transcribing
            } else {
                Button {
                    store.send(.newRecordingTapped)
                } label: {
                    Label(L10n.Recording.newRecording, systemImage: "mic.fill")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.accent)
                }
                .padding(.bottom, Theme.Spacing.xxxl)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private var transcribingContent: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.5)
                .tint(Theme.Colors.accent)

            Text(L10n.Recording.transcribing)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(Theme.Spacing.xxl)
    }

    private func completedContent(_ note: VoiceNote) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Colors.accent)

            Text(L10n.Recording.complete)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .tracking(1.2)

            Text(note.title)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Button {
                store.send(.viewNoteTapped)
            } label: {
                Text(L10n.Recording.viewNote)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        Theme.Colors.accentGradient,
                        in: RoundedRectangle(
                            cornerRadius: Theme.Radius.button,
                            style: .continuous
                        )
                    )
            }
            .modifier(Theme.Shadow.glow())
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .padding(Theme.Spacing.xxl)
    }

    private func failedContent(_ message: String) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text(L10n.Recording.transcriptionFailed)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(message)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xxl)
    }

    // MARK: - Helpers

    private var isRecording: Bool {
        if case .recording = store.recordingState { return true }
        return false
    }

    private var formattedDuration: String {
        let minutes = Int(store.currentDuration) / 60
        let seconds = Int(store.currentDuration) % 60
        let tenths = Int((store.currentDuration * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }

    private var helperText: String {
        switch store.recordingState {
        case .idle:
            L10n.Recording.tapToStart
        case .recording:
            L10n.Recording.tapToStop
        case .processing:
            L10n.Recording.processing
        }
    }
}

#Preview {
    RecordingView(
        store: Store(initialState: RecordingFeature.State()) {
            RecordingFeature()
        }
    )
}
