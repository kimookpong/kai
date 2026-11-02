/// What a gesture should do. Gestures never act directly; this is the only link to the action layer.
public enum GestureAction: String, Sendable, Codable, Equatable {
    case leftButton, rightButton, none
}

/// Maps gesture names to actions so users can remap them. App profiles come in Phase 5.
public struct ActionMapper: Sendable, Equatable {
    public var mapping: [String: GestureAction]

    public init(mapping: [String: GestureAction] = ActionMapper.defaultMapping) { self.mapping = mapping }

    public static let defaultMapping: [String: GestureAction] = [
        PinchFinger.index.gestureName: .leftButton,
        PinchFinger.middle.gestureName: .rightButton,
    ]

    public func action(for gesture: String) -> GestureAction {
        mapping[gesture] ?? .none
    }
}
