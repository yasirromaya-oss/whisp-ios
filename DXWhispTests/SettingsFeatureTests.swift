import ConcurrencyExtras
import ComposableArchitecture
import DXWhispKit
import Foundation
import Testing

@testable import DXWhisp

@MainActor
struct SettingsFeatureTests {
    @Test func onAppearLoadsSettings() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.userDefaults.optionalBool = { key in
                switch key {
                case .autoExportReminders: return true
                case .autoExportCalendar: return true
                default: return nil
                }
            }
        }
        await store.send(.onAppear) {
            $0.autoExportReminders = true
            $0.autoExportCalendar = true
        }
    }

    @Test func onAppearDefaultsFalseWhenNilInDefaults() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.userDefaults.optionalBool = { _ in nil }
        }
        // All default to false, no state mutation expected
        await store.send(.onAppear)
    }

    @Test func toggleAutoExportRemindersGranted() async {
        let persisted = LockIsolated<[UserDefaultsKey: Bool]>([:])
        var state = SettingsFeature.State()
        state.isPro = true
        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: {
            $0.userDefaults.setBool = { key, value in
                persisted.withValue { $0[key] = value }
            }
            $0.eventKit.requestRemindersAccess = { true }
        }
        await store.send(.toggleAutoExportReminders) {
            $0.autoExportReminders = true
        }
        await store.receive(\.requestRemindersPermission)
        #expect(persisted.value[.autoExportReminders] == true)
    }

    @Test func toggleAutoExportRemindersDeniedReverts() async {
        let persisted = LockIsolated<[UserDefaultsKey: Bool]>([:])
        var state = SettingsFeature.State()
        state.isPro = true
        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: {
            $0.userDefaults.setBool = { key, value in
                persisted.withValue { $0[key] = value }
            }
            $0.eventKit.requestRemindersAccess = { false }
        }
        await store.send(.toggleAutoExportReminders) {
            $0.autoExportReminders = true
        }
        await store.receive(\.requestRemindersPermission) {
            $0.autoExportReminders = false
        }
    }

    @Test func toggleAutoExportCalendarGranted() async {
        let persisted = LockIsolated<[UserDefaultsKey: Bool]>([:])
        var state = SettingsFeature.State()
        state.isPro = true
        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: {
            $0.userDefaults.setBool = { key, value in
                persisted.withValue { $0[key] = value }
            }
            $0.eventKit.requestCalendarAccess = { true }
        }
        await store.send(.toggleAutoExportCalendar) {
            $0.autoExportCalendar = true
        }
        await store.receive(\.requestCalendarPermission)
        #expect(persisted.value[.autoExportCalendar] == true)
    }

    @Test func toggleAutoExportCalendarDeniedReverts() async {
        let persisted = LockIsolated<[UserDefaultsKey: Bool]>([:])
        var state = SettingsFeature.State()
        state.isPro = true
        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: {
            $0.userDefaults.setBool = { key, value in
                persisted.withValue { $0[key] = value }
            }
            $0.eventKit.requestCalendarAccess = { false }
        }
        await store.send(.toggleAutoExportCalendar) {
            $0.autoExportCalendar = true
        }
        await store.receive(\.requestCalendarPermission) {
            $0.autoExportCalendar = false
        }
    }

    // MARK: - Subscription Gates

    @Test func upgradeButtonTappedSendsPaywallDelegate() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.upgradeButtonTapped)
        await store.receive(\.delegate.paywallRequested)
    }

    @Test func toggleAutoExportRemindersFreeTierShowsPaywall() async {
        var state = SettingsFeature.State()
        state.isPro = false
        let store = TestStore(initialState: state) {
            SettingsFeature()
        }
        await store.send(.toggleAutoExportReminders)
        await store.receive(\.delegate.paywallRequested)
    }

    @Test func toggleAutoExportCalendarFreeTierShowsPaywall() async {
        var state = SettingsFeature.State()
        state.isPro = false
        let store = TestStore(initialState: state) {
            SettingsFeature()
        }
        await store.send(.toggleAutoExportCalendar)
        await store.receive(\.delegate.paywallRequested)
    }
}
