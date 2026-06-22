import SwiftData
import Foundation

/// Факт разблокировки конкретного достижения.
/// Одна запись = одно достижение разблокировано.
@Model
final class AchievementRecord {
    @Attribute(.unique) var achievementID: String
    var unlockedAt: Date

    init(achievementID: String) {
        self.achievementID = achievementID
        self.unlockedAt = Date()
    }
}
