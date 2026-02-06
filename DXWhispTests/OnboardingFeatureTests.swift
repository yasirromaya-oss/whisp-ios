import ComposableArchitecture
import DXWhispKit
import Foundation
import Testing

@testable import DXWhisp

@MainActor
struct OnboardingFeatureTests {
    @Test func nextPage() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }
        await store.send(.nextPage) {
            $0.currentPage = 1
        }
        await store.send(.nextPage) {
            $0.currentPage = 2
        }
    }

    @Test func nextPageStopsAtEnd() async {
        var state = OnboardingFeature.State()
        state.currentPage = 3
        let store = TestStore(initialState: state) {
            OnboardingFeature()
        }
        await store.send(.nextPage)
    }

    @Test func previousPage() async {
        var state = OnboardingFeature.State()
        state.currentPage = 2
        let store = TestStore(initialState: state) {
            OnboardingFeature()
        }
        await store.send(.previousPage) {
            $0.currentPage = 1
        }
    }

    @Test func previousPageStopsAtBeginning() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }
        await store.send(.previousPage)
    }

    @Test func pageChanged() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }
        await store.send(.pageChanged(3)) {
            $0.currentPage = 3
        }
    }

    @Test func requestPermissionsGranted() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            $0.audioRecorder.requestPermission = { true }
        }
        await store.send(.requestPermissions)
        await store.receive(\.microphonePermissionResult) {
            $0.microphonePermissionGranted = true
        }
        await store.receive(\.completeOnboarding)
    }

    @Test func requestPermissionsDenied() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            $0.audioRecorder.requestPermission = { false }
        }
        await store.send(.requestPermissions)
        await store.receive(\.microphonePermissionResult) {
            $0.microphonePermissionGranted = false
        }
        await store.receive(\.completeOnboarding)
    }
}
