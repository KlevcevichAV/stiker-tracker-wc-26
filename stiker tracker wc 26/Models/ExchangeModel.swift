import SwiftData
import Foundation

enum ExchangeStatus: String {
    case active, completed, cancelled
}

@Model
final class ExchangeModel {

    @Attribute(.unique) var id: String
    var createdAt: Date
    var givingRaw: String    // JSON [{"teamCode":"ARG","number":1,"count":1}]
    var wantingRaw: String   // JSON [{"teamCode":"BRA","number":3,"count":1}]
    var statusRaw: String    // ExchangeStatus.rawValue
    var partner: String      // никнейм/телефон, необязательно

    init(giving: [StickerEntry], wanting: [StickerEntry], partner: String = "") {
        self.id = UUID().uuidString
        self.createdAt = Date()
        self.givingRaw = ExchangeModel.encode(giving)
        self.wantingRaw = ExchangeModel.encode(wanting)
        self.statusRaw = ExchangeStatus.active.rawValue
        self.partner = partner
    }

    var status: ExchangeStatus {
        get { ExchangeStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var giving: [StickerEntry] {
        get { ExchangeModel.decode(givingRaw) }
        set { givingRaw = ExchangeModel.encode(newValue) }
    }

    var wanting: [StickerEntry] {
        get { ExchangeModel.decode(wantingRaw) }
        set { wantingRaw = ExchangeModel.encode(newValue) }
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
