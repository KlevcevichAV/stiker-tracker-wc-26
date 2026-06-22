import Foundation
import SwiftData

struct SeedDataService {

    // MARK: - Public entry point

    static func seedIfNeeded(context: ModelContext) throws {
        let album = try fetchOrCreateAlbum(context: context)
        guard !album.isSeeded else { return }

        guard let url = Bundle.main.url(forResource: "stickers_db", withExtension: "json") else {
            throw SeedError.noDataSource
        }
        let data = try Data(contentsOf: url)
        let sections = try JSONDecoder().decode([DBSection].self, from: data)

        // FWC sections are merged into one team
        let fwcSectionNames: Set<String> = [
            "We Are Panini",
            "FIFA World Cup 2026",
            "Host Countries and Cities",
            "FIFA World Cup History"
        ]

        // Collect ordered team codes (first-appearance order), merging FWC sections
        var order: [String] = []
        var stickersByCode: [String: [DBSticker]] = [:]

        for section in sections {
            let code: String
            if fwcSectionNames.contains(section.sectionName) {
                code = "FWC"
            } else {
                code = sectionToCode[section.sectionName] ?? section.sectionName.uppercased()
            }
            if stickersByCode[code] == nil {
                order.append(code)
                stickersByCode[code] = []
            }
            stickersByCode[code]!.append(contentsOf: section.stickers)
        }

        // Insert teams and stickers
        for (orderIndex, code) in order.enumerated() {
            guard let meta = allTeamMeta[code] else { continue }
            let team = TeamModel(
                code: code,
                nameEN: meta.nameEN,
                nameRU: meta.nameRU,
                groupLetter: meta.group,
                orderIndex: orderIndex,
                flagEmoji: meta.flag
            )
            context.insert(team)

            for dbSticker in stickersByCode[code] ?? [] {
                let number = extractNumber(from: dbSticker.stickerNumber)
                // Если stickerNumber — только цифра (напр. "0" из "We Are Panini"), добавляем код
                let stickerId = dbSticker.stickerNumber.first?.isLetter == true
                    ? dbSticker.stickerNumber
                    : "\(code)\(dbSticker.stickerNumber)"
                let type   = resolveType(number: number, name: dbSticker.fullName)
                let sticker = StickerModel(
                    id: stickerId,
                    teamCode: code,
                    number: number,
                    type: type,
                    nameEN: dbSticker.fullName,
                    nameRU: dbSticker.fullName,
                    isFoil: dbSticker.isShiny
                )
                context.insert(sticker)
            }
        }

        album.isSeeded = true
        try context.save()
    }

    // MARK: - Helpers

    private static func extractNumber(from id: String) -> Int {
        let digits = id.drop(while: { !$0.isNumber })
        return Int(digits) ?? 0
    }

    private static func resolveType(number: Int, name: String) -> StickerType {
        let lower = name.lowercased()
        if number == 1 || lower.contains("emblem") || lower == "panini logo" { return .logo }
        if lower.contains("team photo") { return .teamPhoto }
        return .player
    }

    // MARK: - Album fetch/create

    private static func fetchOrCreateAlbum(context: ModelContext) throws -> AlbumModel {
        let existing = try context.fetch(FetchDescriptor<AlbumModel>())
        if let album = existing.first { return album }
        let album = AlbumModel()
        context.insert(album)
        return album
    }
}

// MARK: - stickers_db.json Decodable types

private struct DBSection: Decodable {
    let sectionName: String
    let stickers: [DBSticker]
}

private struct DBSticker: Decodable {
    let stickerNumber: String
    let fullName: String
    let isShiny: Bool
}

// MARK: - Section name → team code

private let sectionToCode: [String: String] = [
    "Mexico":                   "MEX",
    "South Korea":              "KOR",
    "Czechia":                  "CZE",
    "South Africa":             "RSA",
    "Canada":                   "CAN",
    "Bosnia and Herzegovina":   "BIH",
    "Qatar":                    "QAT",
    "Switzerland":              "SUI",
    "Brazil":                   "BRA",
    "Morocco":                  "MAR",
    "Haiti":                    "HAI",
    "Scotland":                 "SCO",
    "USA":                      "USA",
    "Paraguay":                 "PAR",
    "Australia":                "AUS",
    "Türkiye":                  "TUR",
    "Germany":                  "GER",
    "Curaçao":                  "CUW",
    "Ivory Coast":              "CIV",
    "Ecuador":                  "ECU",
    "Netherlands":              "NED",
    "Japan":                    "JPN",
    "Sweden":                   "SWE",
    "Tunisia":                  "TUN",
    "Belgium":                  "BEL",
    "Egypt":                    "EGY",
    "Iran":                     "IRN",
    "New Zealand":              "NZL",
    "Spain":                    "ESP",
    "Cape Verde":               "CPV",
    "Saudi Arabia":             "KSA",
    "Uruguay":                  "URU",
    "France":                   "FRA",
    "Senegal":                  "SEN",
    "Iraq":                     "IRQ",
    "Norway":                   "NOR",
    "Argentina":                "ARG",
    "Algeria":                  "ALG",
    "Austria":                  "AUT",
    "Jordan":                   "JOR",
    "Portugal":                 "POR",
    "Congo DR":                 "COD",
    "Uzbekistan":               "UZB",
    "Colombia":                 "COL",
    "England":                  "ENG",
    "Croatia":                  "CRO",
    "Ghana":                    "GHA",
    "Panama":                   "PAN",
]

// MARK: - Team metadata

private struct TeamMeta {
    let nameEN: String
    let nameRU: String
    let group: String
    let flag: String
}

private let allTeamMeta: [String: TeamMeta] = [
    "FWC": .init(nameEN: "FIFA World Cup 2026", nameRU: "ЧМ ФИФА 2026",          group: "FWC", flag: "🏆"),
    // Group A
    "MEX": .init(nameEN: "Mexico",              nameRU: "Мексика",                group: "A",   flag: "🇲🇽"),
    "KOR": .init(nameEN: "South Korea",         nameRU: "Южная Корея",            group: "A",   flag: "🇰🇷"),
    "CZE": .init(nameEN: "Czechia",             nameRU: "Чехия",                  group: "A",   flag: "🇨🇿"),
    "RSA": .init(nameEN: "South Africa",        nameRU: "ЮАР",                    group: "A",   flag: "🇿🇦"),
    // Group B
    "CAN": .init(nameEN: "Canada",              nameRU: "Канада",                 group: "B",   flag: "🇨🇦"),
    "BIH": .init(nameEN: "Bosnia & Herzegovina",nameRU: "Босния и Герцеговина",   group: "B",   flag: "🇧🇦"),
    "QAT": .init(nameEN: "Qatar",               nameRU: "Катар",                  group: "B",   flag: "🇶🇦"),
    "SUI": .init(nameEN: "Switzerland",         nameRU: "Швейцария",              group: "B",   flag: "🇨🇭"),
    // Group C
    "BRA": .init(nameEN: "Brazil",              nameRU: "Бразилия",               group: "C",   flag: "🇧🇷"),
    "MAR": .init(nameEN: "Morocco",             nameRU: "Марокко",                group: "C",   flag: "🇲🇦"),
    "HAI": .init(nameEN: "Haiti",               nameRU: "Гаити",                  group: "C",   flag: "🇭🇹"),
    "SCO": .init(nameEN: "Scotland",            nameRU: "Шотландия",              group: "C",   flag: "🏴󠁧󠁢󠁳󠁣󠁴󠁿"),
    // Group D
    "USA": .init(nameEN: "USA",                 nameRU: "США",                    group: "D",   flag: "🇺🇸"),
    "PAR": .init(nameEN: "Paraguay",            nameRU: "Парагвай",               group: "D",   flag: "🇵🇾"),
    "AUS": .init(nameEN: "Australia",           nameRU: "Австралия",              group: "D",   flag: "🇦🇺"),
    "TUR": .init(nameEN: "Türkiye",             nameRU: "Турция",                 group: "D",   flag: "🇹🇷"),
    // Group E
    "GER": .init(nameEN: "Germany",             nameRU: "Германия",               group: "E",   flag: "🇩🇪"),
    "CUW": .init(nameEN: "Curaçao",             nameRU: "Кюрасао",                group: "E",   flag: "🇨🇼"),
    "CIV": .init(nameEN: "Ivory Coast",         nameRU: "Кот-д'Ивуар",           group: "E",   flag: "🇨🇮"),
    "ECU": .init(nameEN: "Ecuador",             nameRU: "Эквадор",                group: "E",   flag: "🇪🇨"),
    // Group F
    "NED": .init(nameEN: "Netherlands",         nameRU: "Нидерланды",             group: "F",   flag: "🇳🇱"),
    "JPN": .init(nameEN: "Japan",               nameRU: "Япония",                 group: "F",   flag: "🇯🇵"),
    "SWE": .init(nameEN: "Sweden",              nameRU: "Швеция",                 group: "F",   flag: "🇸🇪"),
    "TUN": .init(nameEN: "Tunisia",             nameRU: "Тунис",                  group: "F",   flag: "🇹🇳"),
    // Group G
    "BEL": .init(nameEN: "Belgium",             nameRU: "Бельгия",                group: "G",   flag: "🇧🇪"),
    "EGY": .init(nameEN: "Egypt",               nameRU: "Египет",                 group: "G",   flag: "🇪🇬"),
    "IRN": .init(nameEN: "Iran",                nameRU: "Иран",                   group: "G",   flag: "🇮🇷"),
    "NZL": .init(nameEN: "New Zealand",         nameRU: "Новая Зеландия",         group: "G",   flag: "🇳🇿"),
    // Group H
    "ESP": .init(nameEN: "Spain",               nameRU: "Испания",                group: "H",   flag: "🇪🇸"),
    "CPV": .init(nameEN: "Cape Verde",          nameRU: "Кабо-Верде",             group: "H",   flag: "🇨🇻"),
    "KSA": .init(nameEN: "Saudi Arabia",        nameRU: "Саудовская Аравия",      group: "H",   flag: "🇸🇦"),
    "URU": .init(nameEN: "Uruguay",             nameRU: "Уругвай",                group: "H",   flag: "🇺🇾"),
    // Group I
    "FRA": .init(nameEN: "France",              nameRU: "Франция",                group: "I",   flag: "🇫🇷"),
    "SEN": .init(nameEN: "Senegal",             nameRU: "Сенегал",                group: "I",   flag: "🇸🇳"),
    "IRQ": .init(nameEN: "Iraq",                nameRU: "Ирак",                   group: "I",   flag: "🇮🇶"),
    "NOR": .init(nameEN: "Norway",              nameRU: "Норвегия",               group: "I",   flag: "🇳🇴"),
    // Group J
    "ARG": .init(nameEN: "Argentina",           nameRU: "Аргентина",              group: "J",   flag: "🇦🇷"),
    "ALG": .init(nameEN: "Algeria",             nameRU: "Алжир",                  group: "J",   flag: "🇩🇿"),
    "AUT": .init(nameEN: "Austria",             nameRU: "Австрия",                group: "J",   flag: "🇦🇹"),
    "JOR": .init(nameEN: "Jordan",              nameRU: "Иордания",               group: "J",   flag: "🇯🇴"),
    // Group K
    "POR": .init(nameEN: "Portugal",            nameRU: "Португалия",             group: "K",   flag: "🇵🇹"),
    "COD": .init(nameEN: "Congo DR",            nameRU: "ДР Конго",               group: "K",   flag: "🇨🇩"),
    "UZB": .init(nameEN: "Uzbekistan",          nameRU: "Узбекистан",             group: "K",   flag: "🇺🇿"),
    "COL": .init(nameEN: "Colombia",            nameRU: "Колумбия",               group: "K",   flag: "🇨🇴"),
    // Group L
    "ENG": .init(nameEN: "England",             nameRU: "Англия",                 group: "L",   flag: "🏴󠁧󠁢󠁥󠁮󠁧󠁿"),
    "CRO": .init(nameEN: "Croatia",             nameRU: "Хорватия",               group: "L",   flag: "🇭🇷"),
    "GHA": .init(nameEN: "Ghana",               nameRU: "Гана",                   group: "L",   flag: "🇬🇭"),
    "PAN": .init(nameEN: "Panama",              nameRU: "Панама",                 group: "L",   flag: "🇵🇦"),
]

// MARK: - Errors

enum SeedError: LocalizedError {
    case noDataSource

    var errorDescription: String? {
        "stickers_db.json not found in app bundle."
    }
}
