import SwiftUI

// MARK: - Environment key

private struct AchievementsManagerKey: EnvironmentKey {
    static let defaultValue = AchievementsManager()
}

extension EnvironmentValues {
    var achievementsManager: AchievementsManager {
        get { self[AchievementsManagerKey.self] }
        set { self[AchievementsManagerKey.self] = newValue }
    }
}
