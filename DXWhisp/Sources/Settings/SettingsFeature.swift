import ComposableArchitecture
import DXWhispKit

@Reducer
public struct SettingsFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var autoExportReminders: Bool = false
        public var autoExportCalendar: Bool = false
        public var isPro: Bool = false
        public var subscriptionStatus: SubscriptionStatus = .unknown
        public init() {}
    }

    public enum Action: Sendable {
        case onAppear
        case toggleAutoExportReminders
        case toggleAutoExportCalendar
        case requestRemindersPermission(Bool)
        case requestCalendarPermission(Bool)
        case upgradeButtonTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable {
            case paywallRequested
        }
    }

    @Dependency(\.userDefaults) var userDefaults
    @Dependency(\.eventKit) var eventKit

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.autoExportReminders = userDefaults.optionalBool(.autoExportReminders) ?? false
                state.autoExportCalendar = userDefaults.optionalBool(.autoExportCalendar) ?? false
                return .none

            case .toggleAutoExportReminders:
                // Free tier: auto-export requires Pro
                if !state.isPro {
                    return .send(.delegate(.paywallRequested))
                }
                state.autoExportReminders.toggle()
                userDefaults.setBool(.autoExportReminders, state.autoExportReminders)
                if state.autoExportReminders {
                    return .run { send in
                        let granted = await eventKit.requestRemindersAccess()
                        await send(.requestRemindersPermission(granted))
                    }
                }
                return .none

            case let .requestRemindersPermission(granted):
                if !granted {
                    state.autoExportReminders = false
                    userDefaults.setBool(.autoExportReminders, false)
                }
                return .none

            case .toggleAutoExportCalendar:
                // Free tier: auto-export requires Pro
                if !state.isPro {
                    return .send(.delegate(.paywallRequested))
                }
                state.autoExportCalendar.toggle()
                userDefaults.setBool(.autoExportCalendar, state.autoExportCalendar)
                if state.autoExportCalendar {
                    return .run { send in
                        let granted = await eventKit.requestCalendarAccess()
                        await send(.requestCalendarPermission(granted))
                    }
                }
                return .none

            case let .requestCalendarPermission(granted):
                if !granted {
                    state.autoExportCalendar = false
                    userDefaults.setBool(.autoExportCalendar, false)
                }
                return .none

            case .upgradeButtonTapped:
                return .send(.delegate(.paywallRequested))

            case .delegate:
                return .none
            }
        }
    }
}
