import Foundation

/// Прогресс произвольной единицы: команды, группы или всего альбома.
struct ProgressStat {
    let pasted: Int
    let total: Int

    var percent: Double {
        total > 0 ? Double(pasted) / Double(total) : 0
    }

    /// "10 / 20"
    var absoluteString: String { "\(pasted) / \(total)" }

    /// "50%", "25.3%", "25.33%"
    var percentString: String {
        let value = percent * 100
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded() {
            return "\(Int(rounded))%"
        } else if rounded * 10 == (rounded * 10).rounded() {
            return String(format: "%.1f%%", rounded)
        } else {
            return String(format: "%.2f%%", rounded)
        }
    }

    var isComplete: Bool { pasted == total && total > 0 }
}

/// Статистика одной команды.
struct TeamStat {
    let code: String
    let nameEN: String
    let nameRU: String
    let flagEmoji: String
    let groupLetter: String
    let progress: ProgressStat
    let duplicates: Int
}

/// Статистика одной группы (A–L или FWC).
struct GroupStat {
    let letter: String
    let progress: ProgressStat
    let teams: [TeamStat]

    var duplicates: Int { teams.reduce(0) { $0 + $1.duplicates } }
}
