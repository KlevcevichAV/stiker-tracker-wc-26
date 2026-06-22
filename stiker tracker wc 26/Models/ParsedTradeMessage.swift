import Foundation

struct StickerEntry: Identifiable {
    var id: String { "\(teamCode) \(number)" }
    let teamCode: String
    let number: Int
    let count: Int   // кол-во карточек (1 если не указано)
}

struct ParsedTradeMessage {
    var have: [StickerEntry] = []   // повторки / в наличии
    var need: [StickerEntry] = []   // ищу

    enum MessageType { case haveOnly, needOnly, both }

    var messageType: MessageType {
        let hasHave = !have.isEmpty
        let hasNeed = !need.isEmpty
        if hasHave && hasNeed { return .both }
        if hasNeed             { return .needOnly }
        return .haveOnly
    }
}

// Результат сопоставления для одного режима
struct TradeMatch {
    // Режим "взаимный"
    struct MutualResult {
        var theyHaveWeNeed: [StickerEntry] = []
        var weHaveTheyNeed: [StickerEntry] = []
        var weNeedButTheyDontHave: [StickerEntry] = []
        var weHaveButTheyDontNeed: [StickerEntry] = []

        init(theyHaveWeNeed: [StickerEntry] = [],
             weHaveTheyNeed: [StickerEntry] = [],
             weNeedButTheyDontHave: [StickerEntry] = [],
             weHaveButTheyDontNeed: [StickerEntry] = []) {
            self.theyHaveWeNeed = theyHaveWeNeed
            self.weHaveTheyNeed = weHaveTheyNeed
            self.weNeedButTheyDontHave = weNeedButTheyDontHave
            self.weHaveButTheyDontNeed = weHaveButTheyDontNeed
        }
    }
    // Режим 2 / 3 — простой список
    var simpleMatches: [StickerEntry] = []
    var mutual = MutualResult()
}
