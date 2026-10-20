import SwiftUI

extension View {
    /// Plays `feedback` when `trigger` changes, unless haptics are off in Settings.
    func haptic<T: Equatable>(_ feedback: SensoryFeedback, trigger: T) -> some View {
        modifier(HapticModifier(trigger: trigger) { _, _ in feedback })
    }

    /// Picks the feedback from the old and new value; return nil for none.
    func haptic<T: Equatable>(trigger: T, _ feedback: @escaping (T, T) -> SensoryFeedback?) -> some View {
        modifier(HapticModifier(trigger: trigger, feedback: feedback))
    }
}

private struct HapticModifier<T: Equatable>: ViewModifier {
    let trigger: T
    let feedback: (T, T) -> SensoryFeedback?
    @Environment(AppStore.self) private var store

    func body(content: Content) -> some View {
        content.sensoryFeedback(trigger: trigger) { old, new in
            store.hapticsEnabled ? feedback(old, new) : nil
        }
    }
}
