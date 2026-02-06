import Foundation
import SwiftUI

public struct Tag: Equatable, Sendable, Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var color: TagColor

    public init(
        id: UUID = UUID(),
        name: String,
        color: TagColor = .blue
    ) {
        self.id = id
        self.name = name
        self.color = color
    }
}

public enum TagColor: String, Codable, CaseIterable, Equatable, Sendable, Hashable {
    case red, orange, yellow, green, blue, indigo, purple, pink, teal, brown

    public var swiftUIColor: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .teal: .teal
        case .brown: .brown
        }
    }
}
