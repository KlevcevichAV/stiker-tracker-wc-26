import Foundation

// MARK: - Category

enum AchievementCategory: String, CaseIterable {
    case superstar   // пасхалки за конкретного игрока
    case starHunter  // все 10 суперзвёзд
    case team        // полная сборная (48 штук)
    case worldRuler  // все 48 сборных
    case centurion   // 100 наклеек
    case milestone   // 25 / 50 / 75 / 100 %

    var localizedTitle: String {
        switch self {
        case .superstar:   return "Superstar / Суперзвезда"
        case .starHunter:  return "Star Hunter / Охотник за звёздами"
        case .team:        return "National Pride / Национальная гордость"
        case .worldRuler:  return "World Ruler / Абсолютный чемпион"
        case .centurion:   return "Centurion / Первая сотня"
        case .milestone:   return "Milestone / Этап коллекции"
        }
    }

    func localizedTitle(isRu: Bool) -> String {
        switch self {
        case .superstar:   return isRu ? "Суперзвезда" : "Superstar"
        case .starHunter:  return isRu ? "Охотник за звёздами" : "Star Hunter"
        case .team:        return isRu ? "Национальная гордость" : "National Pride"
        case .worldRuler:  return isRu ? "Абсолютный чемпион" : "World Ruler"
        case .centurion:   return isRu ? "Первая сотня" : "Centurion"
        case .milestone:   return isRu ? "Этап коллекции" : "Milestone"
        }
    }
}

// MARK: - Trigger

enum AchievementTrigger: Equatable {
    case stickerPasted(id: String)              // конкретный стикер
    case allStarsPasted                         // все 10 суперзвёзд собраны
    case teamCompleted(code: String)            // все 20 наклеек команды
    case allTeamsCompleted                      // все 48 команд
    case totalPasted(count: Int)               // n вклеенных
    case albumPercent(threshold: Double)       // доля от 980
}

// MARK: - Definition

struct AchievementDefinition: Identifiable {
    let id: String
    let titleEN: String
    let titleRU: String
    let descEN: String
    let descRU: String
    let icon: String          // SF Symbol
    let category: AchievementCategory
    let trigger: AchievementTrigger

    var localizedTitle: String { titleEN }
    var localizedDesc: String  { descEN }

    func localizedTitle(isRu: Bool) -> String { isRu ? titleRU : titleEN }
    func localizedDesc(isRu: Bool)  -> String { isRu ? descRU  : descEN  }
}

// MARK: - Full catalog

extension AchievementDefinition {

    static let all: [AchievementDefinition] = superstarAchievements
        + [starHunter]
        + teamAchievements
        + [worldRuler, firstSticker, centurion]
        + milestones

    // MARK: Superstar easter eggs

    static let superstarStickerIDs: [String] = [
        "ARG17",  // Messi
        "POR15",  // Ronaldo
        "FRA20",  // Mbappé
        "NOR15",  // Haaland
        "ENG11",  // Bellingham
        "BRA14",  // Vinícius Jr
        "CRO9",   // Modrić
        "ESP15",  // Yamal
        "EGY17",  // Salah
        "KOR18",  // Son
    ]

    private static let superstarAchievements: [AchievementDefinition] = [
        .init(id: "star_messi",
              titleEN: "El Capitán / GOAT", titleRU: "Эль Капитан / GOAT",
              descEN: "Lionel Messi — Argentina #17", descRU: "Лионель Месси — Аргентина №17",
              icon: "star.fill", category: .superstar, trigger: .stickerPasted(id: "ARG17")),

        .init(id: "star_ronaldo",
              titleEN: "Siuuu!", titleRU: "Siuuu!",
              descEN: "Cristiano Ronaldo — Portugal #15", descRU: "Криштиану Роналду — Португалия №15",
              icon: "flame.fill", category: .superstar, trigger: .stickerPasted(id: "POR15")),

        .init(id: "star_mbappe",
              titleEN: "Donatello", titleRU: "Донателло",
              descEN: "Kylian Mbappé — France #20", descRU: "Килиан Мбаппе — Франция №20",
              icon: "bolt.fill", category: .superstar, trigger: .stickerPasted(id: "FRA20")),

        .init(id: "star_haaland",
              titleEN: "Terminator", titleRU: "Терминатор",
              descEN: "Erling Haaland — Norway #15", descRU: "Эрлинг Холанд — Норвегия №15",
              icon: "figure.run", category: .superstar, trigger: .stickerPasted(id: "NOR15")),

        .init(id: "star_bellingham",
              titleEN: "Hey Jude", titleRU: "Хей Джуд",
              descEN: "Jude Bellingham — England #11", descRU: "Джуд Беллингем — Англия №11",
              icon: "music.note", category: .superstar, trigger: .stickerPasted(id: "ENG11")),

        .init(id: "star_vini",
              titleEN: "Baila Viní!", titleRU: "Байла Вини!",
              descEN: "Vinícius Júnior — Brazil #14", descRU: "Винисиус Жуниор — Бразилия №14",
              icon: "party.popper.fill", category: .superstar, trigger: .stickerPasted(id: "BRA14")),

        .init(id: "star_modric",
              titleEN: "Maestro", titleRU: "Маэстро",
              descEN: "Luka Modrić — Croatia #9", descRU: "Лука Модрич — Хорватия №9",
              icon: "wand.and.stars", category: .superstar, trigger: .stickerPasted(id: "CRO9")),

        .init(id: "star_yamal",
              titleEN: "Wonderkid", titleRU: "Вундеркинд",
              descEN: "Lamine Yamal — Spain #15", descRU: "Ламин Ямаль — Испания №15",
              icon: "sparkles", category: .superstar, trigger: .stickerPasted(id: "ESP15")),

        .init(id: "star_salah",
              titleEN: "Egyptian King", titleRU: "Египетский король",
              descEN: "Mohamed Salah — Egypt #17", descRU: "Мохаммед Салах — Египет №17",
              icon: "crown.fill", category: .superstar, trigger: .stickerPasted(id: "EGY17")),

        .init(id: "star_son",
              titleEN: "Sonny", titleRU: "Сонни",
              descEN: "Son Heung-min — South Korea #18", descRU: "Сон Хын Мин — Южная Корея №18",
              icon: "heart.fill", category: .superstar, trigger: .stickerPasted(id: "KOR18")),
    ]

    // MARK: Star Hunter

    static let starHunter = AchievementDefinition(
        id: "star_hunter",
        titleEN: "Star Hunter", titleRU: "Охотник за звёздами",
        descEN: "Collect all 10 world superstars", descRU: "Собери всех 10 суперзвёзд мира",
        icon: "star.circle.fill", category: .starHunter, trigger: .allStarsPasted
    )

    // MARK: Team achievements (48 teams) — nickname mapping

    static let teamNicknames: [String: (en: String, ru: String)] = [
        "ARG": ("La Albiceleste",           "Альбиселесте"),
        "BRA": ("Seleção",                  "Селесао"),
        "FRA": ("Les Bleus",                "Синие"),
        "ENG": ("Three Lions",              "Три льва"),
        "ESP": ("La Furia Roja",            "Красная ярость"),
        "GER": ("Die Mannschaft",           "Ди Маншафт"),
        "POR": ("Seleção das Quinas",       "Команда щитов"),
        "NED": ("Oranje",                   "Оранжевые"),
        "BEL": ("Red Devils",               "Красные дьяволы"),
        "CRO": ("Vatreni",                  "Огненные"),
        "URU": ("La Celeste",               "Небесно-голубые"),
        "MEX": ("El Tri",                   "Эль Три"),
        "USA": ("USMNT",                    "Сборная США"),
        "KOR": ("Taeguk Warriors",          "Воины Тэгук"),
        "JPN": ("Samurai Blue",             "Синие самураи"),
        "MAR": ("Atlas Lions",              "Львы Атласа"),
        "SEN": ("Lions of Teranga",         "Львы Теранги"),
        "AUS": ("Socceroos",                "Сокеруз"),
        "SUI": ("Nati",                     "Нати"),
        "CAN": ("Les Rouges",               "Красные"),
        "QAT": ("Al-Annabi",                "Аль-Аннаби"),
        "KSA": ("Green Falcons",            "Зелёные соколы"),
        "TUR": ("Ay-Yıldızlılar",           "Луна со звездой"),
        "PAR": ("La Albirroja",             "Альбирроха"),
        "COL": ("Los Cafeteros",            "Кофейщики"),
        "ECU": ("La Tri",                   "Ла Три"),
        "PER": ("La Blanquirroja",          "Бланкирроха"),
        "CIV": ("Les Éléphants",            "Слоны"),
        "EGY": ("Pharaohs",                 "Фараоны"),
        "GHA": ("Black Stars",              "Чёрные звёзды"),
        "IRN": ("Team Melli",               "Тим Мелли"),
        "NZL": ("All Whites",               "Все белые"),
        "SCO": ("Tartan Army",              "Клетчатая армия"),
        "SWE": ("Blågult",                  "Сине-жёлтые"),
        "NOR": ("Drillo",                   "Дрилло"),
        "ALG": ("Les Fennecs",              "Фенеки"),
        "TUN": ("Eagles of Carthage",       "Орлы Карфагена"),
        "IRQ": ("Lions of Mesopotamia",     "Львы Месопотамии"),
        "JOR": ("Nashama",                  "Нашама"),
        "UZB": ("White Wolves",             "Белые волки"),
        "COD": ("Léopards",                 "Леопарды"),
        "CPV": ("Tubarões Azuis",           "Синие акулы"),
        "BIH": ("Zmajevi",                  "Драконы"),
        "HAI": ("Grenadiers",               "Гренадёры"),
        "CZE": ("Národní tým",              "Национальная сборная"),
        "RSA": ("Bafana Bafana",            "Бафана Бафана"),
        "CUW": ("Wela di Kòrsou",           "Сборная Кюрасао"),
        "AUT": ("Das Team",                 "Дас Тим"),
        "PAN": ("Los Canaleros",            "Каналейрос"),
    ]

    private static let teamAchievements: [AchievementDefinition] = {
        let allTeamCodes: [String] = [
            "FWC",
            "MEX","RSA","KOR","CZE",
            "CAN","SUI","QAT","BIH",
            "BRA","MAR","HAI","SCO",
            "USA","PAR","AUS","TUR",
            "GER","CUW","CIV","ECU",
            "NED","JPN","TUN","SWE",
            "BEL","EGY","IRN","NZL",
            "ESP","CPV","KSA","URU",
            "FRA","SEN","NOR","IRQ",
            "ARG","ALG","AUT","JOR",
            "POR","COL","UZB","COD",
            "ENG","CRO","GHA","PAN",
        ]
        return allTeamCodes.map { code in
            let nick = teamNicknames[code]
            let nameEN = nick?.en ?? code
            let nameRU = nick?.ru ?? code
            return AchievementDefinition(
                id: "team_\(code.lowercased())",
                titleEN: nameEN, titleRU: nameRU,
                descEN: "Complete the \(code) page — all 20 stickers",
                descRU: "Собери все 20 наклеек \(code)",
                icon: "flag.fill",
                category: .team,
                trigger: .teamCompleted(code: code)
            )
        }
    }()

    // MARK: World Ruler

    static let worldRuler = AchievementDefinition(
        id: "world_ruler",
        titleEN: "World Ruler", titleRU: "Абсолютный чемпион",
        descEN: "Complete all 48 national teams", descRU: "Собери все 48 сборных",
        icon: "globe.americas.fill", category: .worldRuler, trigger: .allTeamsCompleted
    )

    // MARK: First Sticker

    static let firstSticker = AchievementDefinition(
        id: "first_sticker",
        titleEN: "First Sticker!", titleRU: "Первая наклейка!",
        descEN: "Paste your very first sticker", descRU: "Вклей свою первую наклейку",
        icon: "hand.tap.fill", category: .milestone, trigger: .totalPasted(count: 1)
    )

    // MARK: Centurion

    static let centurion = AchievementDefinition(
        id: "centurion",
        titleEN: "Centurion", titleRU: "Первая сотня",
        descEN: "Paste 100 stickers", descRU: "Вклей 100 наклеек",
        icon: "100.circle.fill", category: .centurion, trigger: .totalPasted(count: 100)
    )

    // MARK: Milestones

    private static let milestones: [AchievementDefinition] = [
        .init(id: "milestone_25",
              titleEN: "Quarter Way", titleRU: "Четверть пути",
              descEN: "25% of the album collected", descRU: "25% альбома собрано",
              icon: "chart.pie.fill", category: .milestone, trigger: .albumPercent(threshold: 0.25)),
        .init(id: "milestone_50",
              titleEN: "Equator", titleRU: "Экватор",
              descEN: "50% of the album collected", descRU: "50% альбома собрано",
              icon: "circle.righthalf.filled", category: .milestone, trigger: .albumPercent(threshold: 0.50)),
        .init(id: "milestone_75",
              titleEN: "Final Stretch", titleRU: "Финишная прямая",
              descEN: "75% of the album collected", descRU: "75% альбома собрано",
              icon: "chart.bar.fill", category: .milestone, trigger: .albumPercent(threshold: 0.75)),
        .init(id: "milestone_100",
              titleEN: "Legend", titleRU: "Легенда коллекционирования",
              descEN: "Complete the entire album!", descRU: "Полностью собери весь альбом!",
              icon: "trophy.fill", category: .milestone, trigger: .albumPercent(threshold: 1.0)),
    ]
}
