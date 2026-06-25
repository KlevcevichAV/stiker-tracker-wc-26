import SwiftData
import Foundation
import SwiftUI

// MARK: - Trust level

enum TrustLevel {
    case good    // есть завершённые обмены
    case medium  // нет истории, или только причина "не договорились"
    case bad     // есть отказы "не пришёл" или "не отвечает"

    var icon: String {
        switch self {
        case .good:   return "hand.thumbsup.fill"
        case .medium: return "minus.circle.fill"
        case .bad:    return "hand.thumbsdown.fill"
        }
    }

    var color: Color {
        switch self {
        case .good:   return .green
        case .medium: return .orange
        case .bad:    return .red
        }
    }

    var nameRU: String {
        switch self {
        case .good:   return "Надёжный"
        case .medium: return "Нейтральный"
        case .bad:    return "Ненадёжный"
        }
    }

    var nameEN: String {
        switch self {
        case .good:   return "Reliable"
        case .medium: return "Neutral"
        case .bad:    return "Unreliable"
        }
    }

    static func compute(for partner: String, in exchanges: [ExchangeModel]) -> TrustLevel? {
        guard !partner.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let history = exchanges.filter { $0.partner == partner }
        guard !history.isEmpty else { return nil }

        let hasCompleted = history.contains { $0.status == .completed }
        if hasCompleted { return .good }

        let badReasons: Set<CancellationReason> = [.noShow, .noResponse]
        let hasBad = history.contains { ex in
            guard let r = ex.cancellationReason else { return false }
            return badReasons.contains(r)
        }
        if hasBad { return .bad }

        return .medium
    }
}

enum ExchangeStatus: String {
    case active, completed, cancelled
}

enum CancellationReason: String, CaseIterable {
    case noShow      // не пришёл
    case noResponse  // не отвечает
    case noAgreement // не договорились

    var nameRU: String {
        switch self {
        case .noShow:      return "Не пришёл"
        case .noResponse:  return "Не отвечает"
        case .noAgreement: return "Не договорились"
        }
    }

    var nameEN: String {
        switch self {
        case .noShow:      return "No show"
        case .noResponse:  return "No response"
        case .noAgreement: return "No agreement"
        }
    }

    var icon: String {
        switch self {
        case .noShow:      return "person.slash.fill"
        case .noResponse:  return "message.badge.slash.fill"
        case .noAgreement: return "xmark.seal.fill"
        }
    }

    var color: Color {
        switch self {
        case .noShow:      return .red
        case .noResponse:  return .yellow
        case .noAgreement: return .green
        }
    }
}

@Model
final class ExchangeModel {

    @Attribute(.unique) var id: String
    var createdAt: Date
    var meetingDate: Date?
    var givingRaw: String    // JSON [{"teamCode":"ARG","number":1,"count":1}]
    var wantingRaw: String   // JSON [{"teamCode":"BRA","number":3,"count":1}]
    var statusRaw: String    // ExchangeStatus.rawValue
    var partner: String      // никнейм/телефон, необязательно
    var cancellationReasonRaw: String?  // CancellationReason.rawValue, только для cancelled
    var isArchived: Bool = false     // true — создан как архивный, альбом не менялся

    init(giving: [StickerEntry], wanting: [StickerEntry], partner: String = "", meetingDate: Date = Date()) {
        self.id = UUID().uuidString
        self.createdAt = Date()
        self.meetingDate = meetingDate
        self.givingRaw = ExchangeModel.encode(giving)
        self.wantingRaw = ExchangeModel.encode(wanting)
        self.statusRaw = ExchangeStatus.active.rawValue
        self.partner = partner
        self.isArchived = false
    }

    /// Дата встречи с фолбэком на дату создания (для старых записей без meetingDate)
    var effectiveMeetingDate: Date { meetingDate ?? createdAt }

    var status: ExchangeStatus {
        get { ExchangeStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var cancellationReason: CancellationReason? {
        get { cancellationReasonRaw.flatMap { CancellationReason(rawValue: $0) } }
        set { cancellationReasonRaw = newValue?.rawValue }
    }

    var giving: [StickerEntry] {
        get { ExchangeModel.decode(givingRaw) }
        set { givingRaw = ExchangeModel.encode(newValue) }
    }

    var wanting: [StickerEntry] {
        get { ExchangeModel.decode(wantingRaw) }
        set { wantingRaw = ExchangeModel.encode(newValue) }
    }

    /// Изменение кол-ва наклеек в результате этого обмена: получено − отдано.
    /// Для 1:1 обменов равно 0. Для не-1:1 — положительное или отрицательное.
    var netStickerDelta: Int {
        let got  = wanting.reduce(0) { $0 + $1.count }
        let gave = giving.reduce(0)  { $0 + $1.count }
        return got - gave
    }

    // MARK: - Restore from backup

    static func __restore(
        id: String,
        createdAt: Date,
        givingRaw: String,
        wantingRaw: String,
        statusRaw: String,
        partner: String,
        meetingDate: Date? = nil
    ) -> ExchangeModel {
        let ex = ExchangeModel(giving: [], wanting: [], partner: partner)
        ex.id = id
        ex.createdAt = createdAt
        ex.meetingDate = meetingDate ?? createdAt
        ex.givingRaw = givingRaw
        ex.wantingRaw = wantingRaw
        ex.statusRaw = statusRaw
        return ex
    }

    // MARK: - Helpers

    private static func encode(_ entries: [StickerEntry]) -> String {
        let dicts = entries.map { ["teamCode": $0.teamCode, "number": "\($0.number)", "count": "\($0.count)"] }
        let data = try? JSONSerialization.data(withJSONObject: dicts)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    private static func decode(_ raw: String) -> [StickerEntry] {
        guard let data = raw.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: String]]
        else { return [] }
        return arr.compactMap { dict in
            guard let tc = dict["teamCode"],
                  let numStr = dict["number"], let num = Int(numStr),
                  let cntStr = dict["count"], let cnt = Int(cntStr)
            else { return nil }
            return StickerEntry(teamCode: tc, number: num, count: cnt)
        }
    }
}
