import SwiftUI
import UIKit

enum SettingsKey {
    static let soundsAndHaptics = "soundsAndHaptics"
    static let parentPIN = "parentPIN"
    static let disabledPatterns = "disabledPatterns"
}

/// Haptics (STYLE §9). Respects the Parent corner switch. The game has no speech: text only.
@MainActor
final class Feedback {
    static let shared = Feedback()

    private let impact = UIImpactFeedbackGenerator(style: .light)
    private let notify = UINotificationFeedbackGenerator()
    private let select = UISelectionFeedbackGenerator()

    private var hapticsOn: Bool { UserDefaults.standard.object(forKey: SettingsKey.soundsAndHaptics) as? Bool ?? true }

    /// Warms up the haptic engine so the first answer responds instantly.
    func prepare() {
        impact.prepare()
        notify.prepare()
        select.prepare()
    }

    func lean() { if hapticsOn { select.selectionChanged() } }
    func correct() { if hapticsOn { impact.impactOccurred() } }
    func wrong() { if hapticsOn { notify.notificationOccurred(.error) } }
    func celebrate() { if hapticsOn { notify.notificationOccurred(.success) } }
    func tick() { if hapticsOn { impact.impactOccurred(intensity: 0.45) } }
}

// MARK: - Launching games from anywhere in the UI

struct LaunchGame {
    let action: (GameConfig) -> Void
    func callAsFunction(_ config: GameConfig) { action(config) }
}

private struct LaunchGameKey: EnvironmentKey {
    static let defaultValue = LaunchGame { _ in }
}

extension EnvironmentValues {
    var launchGame: LaunchGame {
        get { self[LaunchGameKey.self] }
        set { self[LaunchGameKey.self] = newValue }
    }
}
