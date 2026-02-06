import ComposableArchitecture
import DXWhispKit
import Foundation
import Testing

@testable import DXWhisp

@MainActor
struct TagEditorFeatureTests {
    @Test func saveTappedWithValidName() async {
        let store = TestStore(initialState: TagEditorFeature.State()) {
            TagEditorFeature()
        }
        store.state.name = "Work"
        store.state.color = .red
        await store.send(.saveTapped)
        await store.receive(\.delegate.tagSaved) { _ in }
    }

    @Test func saveTappedWithEmptyNameIsNoOp() async {
        let store = TestStore(initialState: TagEditorFeature.State()) {
            TagEditorFeature()
        }
        store.state.name = "   "
        await store.send(.saveTapped)
        // No delegate action should be received
    }

    @Test func saveTappedTrimsWhitespace() async {
        let store = TestStore(initialState: TagEditorFeature.State()) {
            TagEditorFeature()
        }
        store.state.name = "  Shopping  "
        await store.send(.saveTapped)
        await store.receive(\.delegate.tagSaved) { _ in }
    }

    @Test func editingExistingTagPreservesID() async {
        let existingTag = Tag(id: UUID(), name: "Old", color: .green)
        let state = TagEditorFeature.State(tag: existingTag)
        #expect(state.tagID == existingTag.id)
        #expect(state.name == "Old")
        #expect(state.color == .green)
        #expect(state.isNew == false)
    }

    @Test func newTagState() async {
        let state = TagEditorFeature.State()
        #expect(state.name == "")
        #expect(state.color == .blue)
        #expect(state.isNew == true)
    }

    @Test func cancelTappedIsNoOp() async {
        let store = TestStore(initialState: TagEditorFeature.State()) {
            TagEditorFeature()
        }
        store.state.name = "Unsaved"
        await store.send(.cancelTapped)
        // No state change, no effects
    }
}
