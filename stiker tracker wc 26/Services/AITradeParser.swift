import Foundation

enum AITradeParser {

    private static let apiURL = URL(string: "https://api.openmodel.ai/v1/messages")!
    private static let model  = "claude-haiku-4-5-20251001"

    static var apiKey: String {
        UserDefaults.standard.string(forKey: "openModelAPIKey") ?? ""
    }

    static var hasAPIKey: Bool {
        !apiKey.isEmpty
    }

    private static let systemPrompt = """
    You are a sticker trade message parser. Your task is to extract two lists from a sticker trade message:
    1. "have" — stickers the person HAS (duplicates they're offering for trade)
    2. "need" — stickers the person NEEDS (they're looking for these)

    Common section headers in messages:
    - "have" / "повторки" / "есть" / "на обмен" / "дубли" → these are "have" entries
    - "need" / "ищу" / "нужны" / "looking for" → these are "need" entries

    Each sticker is identified by a team code (3-4 uppercase Latin letters) and a number.
    Examples: "ARG 1", "FWC 12", "BRA 5"

    Return ONLY a valid JSON object with exactly this structure:
    {
      "have": [{"teamCode": "ARG", "number": 1}, {"teamCode": "BRA", "number": 5}],
      "need": [{"teamCode": "FWC", "number": 12}]
    }

    Rules:
    - Use uppercase team codes (3-4 letters)
    - Numbers must be integers
    - If a section is absent or empty, return an empty array []
    - Do NOT include any text outside the JSON object
    - Do NOT include markdown code fences
    """

    static func parse(text: String) async throws -> ParsedTradeMessage {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": text]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let raw = String(data: data, encoding: .utf8) ?? "unknown error"
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "API error \(http.statusCode): \(raw)"])
        }

        // Parse Anthropic Messages response: { "content": [{ "type": "text", "text": "..." }] }
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]],
            let firstBlock = content.first,
            firstBlock["type"] as? String == "text",
            let aiText = firstBlock["text"] as? String
        else {
            throw URLError(.cannotParseResponse, userInfo: [NSLocalizedDescriptionKey: "Unexpected API response format"])
        }

        return try parseAIResponse(aiText)
    }

    private static func parseAIResponse(_ text: String) throws -> ParsedTradeMessage {
        // Strip markdown fences if the model added them anyway
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .components(separatedBy: "\n")
                .dropFirst()
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard
            let data = cleaned.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw URLError(.cannotParseResponse, userInfo: [NSLocalizedDescriptionKey: "AI returned invalid JSON"])
        }

        func entries(from key: String) -> [StickerEntry] {
            guard let arr = json[key] as? [[String: Any]] else { return [] }
            return arr.compactMap { item -> StickerEntry? in
                guard
                    let code = item["teamCode"] as? String,
                    let number = item["number"] as? Int
                else { return nil }
                return StickerEntry(teamCode: code, number: number, count: 1)
            }
        }

        var result = ParsedTradeMessage()
        result.have = entries(from: "have")
        result.need = entries(from: "need")
        return result
    }
}
