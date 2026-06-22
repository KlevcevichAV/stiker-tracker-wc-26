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

    /// "50%"
    var percentString: String {
        let value = Int((percent * 100).rounded())
        return "\(value)%"
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
