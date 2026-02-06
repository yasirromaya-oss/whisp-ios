import ComposableArchitecture
import DXWhispKit
import Foundation

@Reducer
public struct TagEditorFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var tagID: UUID
        public var name: String
        public var color: TagColor
        public var isNew: Bool

        public init(tag: Tag? = nil) {
            if let tag {
                self.tagID = tag.id
                self.name = tag.name
                self.color = tag.color
                self.isNew = false
            } else {
                self.tagID = UUID()
                self.name = ""
                self.color = .blue
                self.isNew = true
            }
        }
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case saveTapped
        case cancelTapped
        case delegate(Delegate)

        public enum Delegate: Sendable, Equatable {
            case tagSaved(Tag)
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .saveTapped:
                let trimmed = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return .none }
                let tag = Tag(id: state.tagID, name: trimmed, color: state.color)
                return .send(.delegate(.tagSaved(tag)))

            case .cancelTapped:
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
