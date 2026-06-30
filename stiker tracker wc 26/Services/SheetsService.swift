import Foundation

enum SheetsService {

    static var scriptURL: String {
        get {
            UserDefaults.standard.string(forKey: "sheetsScriptURL")
                ?? "https://script.google.com/macros/s/AKfycbwU9HtJGHbAnZF4RIp1Ry8_VOIAT724Ho2e6-Z1ZKGTDhBTuUnthtgUk2YufNDlgUfF/exec"
        }
        set { UserDefaults.standard.set(newValue, forKey: "sheetsScriptURL") }
    }

    private static var isEnabled: Bool { !scriptURL.isEmpty }

    // MARK: - Fire-and-forget (для автоматических событий)

    static func sendExchangeCreated(id: String, partner: String, giving: [StickerEntry], wanting: [StickerEntry]) {
        guard isEnabled else { return }
        Task { try? await sendGETAsync(exchangePayload(event: "exchange_created", id: id, partner: partner, giving: giving, wanting: wanting)) }
    }

    static func sendExchangeUpdated(id: String, partner: String, giving: [StickerEntry], wanting: [StickerEntry]) {
        guard isEnabled else { return }
        Task { try? await sendGETAsync(exchangePayload(event: "exchange_updated", id: id, partner: partner, giving: giving, wanting: wanting)) }
    }

    static func sendExchangeCompleted(id: String, partner: String, giving: [StickerEntry], wanting: [StickerEntry]) {
        guard isEnabled else { return }
        Task { try? await sendGETAsync(exchangePayload(event: "exchange_completed", id: id, partner: partner, giving: giving, wanting: wanting)) }
    }

    static func sendExchangeCancelled(id: String, partner: String, giving: [StickerEntry], wanting: [StickerEntry]) {
        guard isEnabled else { return }
        Task { try? await sendGETAsync(exchangePayload(event: "exchange_cancelled", id: id, partner: partner, giving: giving, wanting: wanting)) }
    }

    static func sendPurchase(kind: String, quantity: Int, price: Double, totalCost: Double, stickerCount: Int) {
        guard isEnabled else { return }
        let payload: [String: Any] = [
            "event": "purchase",
            "date": isoNow(),
            "kind": kind,
            "quantity": quantity,
            "price_each": price,
            "total_cost": totalCost,
            "sticker_count": stickerCount
        ]
        Task { try? await sendGETAsync(payload) }
    }

    // MARK: - Async (для syncAll с отслеживанием прогресса)

    static func syncAll(exchanges: [ExchangeModel], purchases: [PurchaseModel],
                        stickers: [StickerModel], teams: [TeamModel],
                        isRu: Bool,
                        progress: @escaping (Int, Int) -> Void) async {
        guard isEnabled else { return }

        var payloads: [[String: Any]] = []

        for ex in exchanges {
            if ex.status == .completed {
                payloads.append(exchangePayload(event: "exchange_completed", id: ex.id, partner: ex.partner, giving: ex.giving, wanting: ex.wanting))
            } else if ex.status == .active {
                payloads.append(exchangePayload(event: "exchange_created", id: ex.id, partner: ex.partner, giving: ex.giving, wanting: ex.wanting))
            }
        }

        for p in purchases {
            payloads.append([
                "event": "purchase",
                "date": isoNow(),
                "kind": isRu ? p.kind.nameRU : p.kind.nameEN,
                "quantity": p.quantity,
                "price_each": p.price,
                "total_cost": p.totalCost,
                "sticker_count": p.stickerCount
            ])
        }

        let total = payloads.count + 1
        let counter = Counter()

        await withTaskGroup(of: Void.self) { group in
            for payload in payloads {
                group.addTask {
                    try? await sendGETAsync(payload)
                    let done = await counter.increment()
                    progress(done, total)
                }
            }
        }

        await sendCollectionPayload(stickers: stickers, teams: teams)
        progress(total, total)
    }

    private actor Counter {
        private var value = 0
        func increment() -> Int {
            value += 1
            return value
        }
    }

    // MARK: - Private

    private static func sendCollectionPayload(stickers: [StickerModel], teams: [TeamModel]) async {
        let byTeam = Dictionary(grouping: stickers, by: \.teamCode)
        let sortedTeams = teams.sorted { $0.orderIndex < $1.orderIndex }
        let teamRows: [[String: Any]] = sortedTeams.compactMap { team in
            guard let group = byTeam[team.code] else { return nil }
            let duplicates = group
                .filter { $0.duplicateCount > 0 }
                .sorted { $0.number < $1.number }
                .map { s in s.duplicateCount > 1 ? "\(s.number)×\(s.duplicateCount)" : "\(s.number)" }
                .joined(separator: ", ")
            let missing = group
                .filter { $0.status == .missing }
                .sorted { $0.number < $1.number }
                .map { "\($0.number)" }
                .joined(separator: ", ")
            return ["team": team.code, "group": team.groupLetter, "duplicates": duplicates, "missing": missing]
        }

        // Первый чанк — с clear:true, остальные — с clear:false (дозаписываем)
        let chunkSize = 10
        let chunks = stride(from: 0, to: teamRows.count, by: chunkSize).map {
            Array(teamRows[$0..<min($0 + chunkSize, teamRows.count)])
        }
        for (i, chunk) in chunks.enumerated() {
            // Передаём группу последней команды предыдущего чанка для корректных разделителей
            let prevGroup = i > 0 ? (chunks[i-1].last?["group"] as? String ?? "") : ""
            let payload: [String: Any] = [
                "event": "collection",
                "date": isoNow(),
                "teams": chunk,
                "clear": i == 0,
                "prev_group": prevGroup
            ]
            try? await sendPOSTAsync(payload)
        }
    }

    private static func exchangePayload(event: String, id: String, partner: String,
                                        giving: [StickerEntry], wanting: [StickerEntry]) -> [String: Any] {
        [
            "event": event,
            "id": id,
            "date": isoNow(),
            "partner": partner,
            "giving": format(giving),
            "wanting": format(wanting),
            "giving_count": giving.reduce(0) { $0 + $1.count },
            "wanting_count": wanting.reduce(0) { $0 + $1.count }
        ]
    }

    private static func sendGETAsync(_ payload: [String: Any]) async throws {
        guard let json = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: json, encoding: .utf8),
              let encoded = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: scriptURL + "?payload=" + encoded) else { return }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse {
            print("[SheetsService] GET Status: \(http.statusCode)")
        }
        if let body = String(data: data, encoding: .utf8) {
            print("[SheetsService] GET Response: \(body)")
        }
    }

    private static func sendPOSTAsync(_ payload: [String: Any]) async throws {
        guard let url = URL(string: scriptURL),
              let json = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = json
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            print("[SheetsService] POST Status: \(http.statusCode)")
        }
        if let body = String(data: data, encoding: .utf8) {
            print("[SheetsService] POST Response: \(body)")
        }
    }

    private static func isoNow() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func format(_ entries: [StickerEntry]) -> String {
        entries.map { e in e.count > 1 ? "\(e.teamCode)\(e.number)×\(e.count)" : "\(e.teamCode)\(e.number)" }
               .joined(separator: ", ")
    }
}
