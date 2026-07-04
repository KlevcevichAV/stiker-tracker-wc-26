import Foundation

/// Парсит текстовые сообщения об обмене стикерами.
/// Поддерживает все форматы из реальных чатов: с эмодзи/без, с двоеточием/без,
/// с множителями (x2), (2), *2, повторяющимися номерами, ведущими/хвостовыми запятыми.
enum TradeMessageParser {

    // MARK: - Public

    static func parse(_ text: String) -> ParsedTradeMessage {
        let lines = text.components(separatedBy: .newlines)

        // Ключевые слова секций (нижний регистр)
        let haveKeywords  = ["повторки", "в наличии", "все повторки", "есть на обмен", "на обмен", "повторы (есть)"]
        let needKeywords  = ["ищу", "нужны", "нужно", "ищу (нужно)"]
        // "обмен" само по себе — вводная фраза, не заголовок секции
        let sectionSep    = "00"

        enum Section { case have, need, unknown }
        var currentSection: Section = .unknown

        var haveLines: [String] = []
        var needLines: [String] = []

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            let lower = line.lowercased()

            // Пропускаем пустые и мусорные строки
            if line.isEmpty { continue }

            // Нотация-торг — пропускаем строку целиком
            if line.range(of: #"\d+\(\d+на\d+\)"#, options: .regularExpression) != nil { continue }

            // Разделитель секций "00"
            if line == sectionSep { continue }

            // Определяем заголовок секции
            if haveKeywords.contains(where: { lower.contains($0) })
                && !containsTeamCode(line) {
                currentSection = .have
                continue
            }
            if needKeywords.contains(where: { lower.contains($0) })
                && !containsTeamCode(line) {
                currentSection = .need
                continue
            }

            // Если ещё не встретили явный заголовок, строки с командами идут в "have"
            if currentSection == .unknown && containsTeamCode(line) {
                currentSection = .have
            }

            // Пропускаем строки без кода команды
            guard containsTeamCode(line) else { continue }

            switch currentSection {
            case .have, .unknown: haveLines.append(line)
            case .need:           needLines.append(line)
            }
        }

        var result = ParsedTradeMessage()
        result.have = haveLines.flatMap { parseTeamLine($0) }
        result.need = needLines.flatMap { parseTeamLine($0) }
        return result
    }

    // MARK: - Private: check for team code

    /// Проверяет, содержит ли строка код команды (3–4 латинские буквы в любом регистре)
    private static func containsTeamCode(_ line: String) -> Bool {
        let pattern = #"(?<![A-Za-z])[A-Za-z]{3,4}(?![A-Za-z])"#
        return line.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Private: parse one team line

    /// Парсит строку в двух форматах:
    /// 1. "КОД ЧИСЛО, ЧИСЛО, ..." — одна команда, несколько номеров (с эмодзи/двоеточием)
    ///    Пример: "ARG 🇦🇷: 1(x2), 5, 8"
    /// 2. "КОД1ЧИСЛО, КОД1ЧИСЛО, КОД2ЧИСЛО, ..." — несколько команд в строке без пробела
    ///    Пример: "FWC0, FWC1, KOR8, KOR11(2)"
    private static func parseTeamLine(_ line: String) -> [StickerEntry] {
        // Сначала пробуем формат 2: токены вида КОДЧИСЛО[(N)] через запятую
        // Паттерн: 3-4 заглавные буквы сразу за которыми число (без пробела)
        let compactPattern = #"([A-Za-z]{3,4})(\d+)\s*(?:\([xхх×]?(\d+)\)|\*(\d+))?"#
        let compactRegex = try? NSRegularExpression(pattern: compactPattern)
        let nsLine = line as NSString
        let compactMatches = compactRegex?.matches(in: line, range: NSRange(line.startIndex..., in: line)) ?? []

        if !compactMatches.isEmpty {
            var countByKey: [String: (teamCode: String, number: Int, count: Int)] = [:]
            for m in compactMatches {
                guard let rCode = Range(m.range(at: 1), in: line),
                      let rNum  = Range(m.range(at: 2), in: line),
                      let num   = Int(line[rNum]) else { continue }
                let code = String(line[rCode]).uppercased()
                var qty = 1
                if m.range(at: 3).location != NSNotFound,
                   let r3 = Range(m.range(at: 3), in: line), let q = Int(line[r3]) { qty = q }
                else if m.range(at: 4).location != NSNotFound,
                        let r4 = Range(m.range(at: 4), in: line), let q = Int(line[r4]) { qty = q }
                let key = "\(code) \(num)"
                if var existing = countByKey[key] {
                    existing.count += qty
                    countByKey[key] = existing
                } else {
                    countByKey[key] = (teamCode: code, number: num, count: qty)
                }
            }
            _ = nsLine
            return countByKey.values
                .sorted { $0.teamCode == $1.teamCode ? $0.number < $1.number : $0.teamCode < $1.teamCode }
                .map { StickerEntry(teamCode: $0.teamCode, number: $0.number, count: $0.count) }
        }

        // Формат 1: "КОД [эмодзи] [: ] ЧИСЛО, ЧИСЛО, ..."
        guard let codeRange = line.range(of: #"(?<![A-Za-z])[A-Za-z]{3,4}(?![A-Za-z])"#,
                                          options: .regularExpression) else { return [] }
        let teamCode = String(line[codeRange]).uppercased()
        let afterCode = String(line[codeRange.upperBound...])
        let numbersString = stripFlagsAndColon(afterCode)
        let stripped = numbersString.trimmingCharacters(in: .whitespaces)
        if stripped.isEmpty || stripped == "-" || stripped == "—" { return [] }
        return parseNumbers(stripped, teamCode: teamCode)
    }

    // MARK: - Strip emoji flags and colon

    private static func stripFlagsAndColon(_ s: String) -> String {
        var result = ""
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            // Пропускаем скалярные значения флагов (региональные индикаторы) и другие эмодзи
            let scalar = c.unicodeScalars.first!.value
            if (scalar >= 0x1F1E0 && scalar <= 0x1F1FF)  // региональные индикаторы A–Z
                || (scalar >= 0x1F3F3 && scalar <= 0x1F3FF)  // флаги (🏳–🏿)
                || scalar == 0xFE0F                            // variation selector
                || (scalar >= 0xE0000 && scalar <= 0xE007F)   // tags (шотландский флаг)
            {
                i = s.index(after: i)
                continue
            }
            // Пропускаем двоеточие в начале остатка
            if c == ":" && result.trimmingCharacters(in: .whitespaces).isEmpty {
                i = s.index(after: i)
                continue
            }
            result.append(c)
            i = s.index(after: i)
        }
        // Убираем ведущее двоеточие если осталось
        return result.trimmingCharacters(in: CharacterSet(charactersIn: ": "))
                     .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Parse numbers string

    /// Парсит строку типа "1(x2), 5, 8(x3), 14 (2)" в массив StickerEntry
    private static func parseNumbers(_ s: String, teamCode: String) -> [StickerEntry] {
        // Токенизируем по запятой или слэшу
        let tokens = s.components(separatedBy: CharacterSet(charactersIn: ",/"))

        // Считаем повторы одинаковых номеров (формат PAR1,1,1)
        var countByNumber: [Int: Int] = [:]

        for token in tokens {
            let t = token.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { continue }

            // Ищем число и опциональный множитель
            // Паттерны: 14 (2), 14(x2), 14(x3), 14*2
            // Нотацию торга (xнаy) уже отфильтровали раньше

            // Ищем все числа в токене
            let numPattern = #"(\d+)\s*(?:\([xхх×]?(\d+)\)|\*(\d+))?"#
            guard let match = t.range(of: numPattern, options: .regularExpression) else { continue }

            // Вытаскиваем через NSRegularExpression для групп
            let nsStr = t as NSString
            let regex = try? NSRegularExpression(pattern: numPattern)
            guard let m = regex?.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) else { continue }

            guard let r0 = Range(m.range(at: 1), in: t), let num = Int(t[r0]) else { continue }

            var qty = 1
            // Группа 2: (xN) или (N)
            if m.range(at: 2).location != NSNotFound,
               let r2 = Range(m.range(at: 2), in: t),
               let q = Int(t[r2]) {
                qty = q
            }
            // Группа 3: *N
            else if m.range(at: 3).location != NSNotFound,
                    let r3 = Range(m.range(at: 3), in: t),
                    let q = Int(t[r3]) {
                qty = q
            }

            // Если число уже встречалось — суммируем (PAR1,1,1 → 3)
            countByNumber[num, default: 0] += qty
            _ = match  // suppress warning
            _ = nsStr
        }

        return countByNumber.map { num, cnt in
            StickerEntry(teamCode: teamCode, number: num, count: cnt)
        }.sorted { $0.number < $1.number }
    }
}
