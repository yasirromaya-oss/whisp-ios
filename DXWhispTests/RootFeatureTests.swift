import ComposableArchitecture
import DXWhispKit
import Foundation
import Testing

@testable import DXWhisp

@MainActor
struct RootFeatureTests {
    @Test func loadOnboardingStatusCompleted() async {
        let store = TestStore(initialState: RootFeature.State()) {
            RootFeature()
        } withDependencies: {
            $0.userDefaults.getBool = { key in
                key == .hasCompletedOnboarding ? true : false
            }
        }
        await store.send(.loadOnboardingStatus)
        await store.receive(\.setOnboardingCompleted) {
            $0.hasCompletedOnboarding = true
            $0.hasLoaded = true
        }
    }

    @Test func loadOnboardingStatusNotCompleted() async {
        let store = TestStore(initialState: RootFeature.State()) {
            RootFeature()
        } withDependencies: {
            $0.userDefaults.getBool = { _ in false }
        }
        await store.send(.loadOnboardingStatus)
        await store.receive(\.setOnboardingCompleted) {
            $0.hasLoaded = true
        }
    }

    @Test func completeOnboardingSetsFlag() async {
        let setBoolCalls = LockIsolated<[(UserDefaultsKey, Bool)]>([])
        let store = TestStore(initialState: RootFeature.State()) {
            RootFeature()
        } withDependencies: {
            $0.userDefaults.setBool = { key, value in
                setBoolCalls.withValue { $0.append((key, value)) }
            }
        }
        await store.send(.onboarding(.completeOnboarding)) {
            $0.hasCompletedOnboarding = true
        }
        #expect(setBoolCalls.value.count == 1)
        #expect(setBoolCalls.value[0].0 == .hasCompletedOnboarding)
        #expect(setBoolCalls.value[0].1 == true)
    }

}
