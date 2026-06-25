import SwiftData
import Foundation

enum PurchaseKind: String, CaseIterable {
    case album, pack, blister3, blister8

    var nameRU: String {
        switch self {
        case .album:    return "Журнал"
        case .pack:     return "Пак"
        case .blister3: return "Блистер ×3"
        case .blister8: return "Блистер ×8"
        }
    }

    var nameEN: String {
        switch self {
        case .album:    return "Album"
        case .pack:     return "Pack"
        case .blister3: return "Blister ×3"
        case .blister8: return "Blister ×8"
        }
    }

    var defaultPrice: Double? {
        switch self {
        case .album:    return 17.99
        case .pack:     return 4.99
        case .blister3: return 15.99
        case .blister8: return 45.99
        }
    }

    /// Наклеек в одной единице товара
    var stickersPerUnit: Int {
        switch self {
        case .album:    return 0
        case .pack:     return 7
        case .blister3: return 21   // 3 пака × 7
        case .blister8: return 56   // 8 паков × 7
        }
    }

    /// Паков в одной единице товара
    var packsPerUnit: Int {
        switch self {
        case .album:    return 0
        case .pack:     return 1
        case .blister3: return 3
        case .blister8: return 8
        }
    }

    var icon: String {
        switch self {
        case .album:    return "book.closed.fill"
        case .pack:     return "envelope.fill"
        case .blister3: return "square.stack.fill"
        case .blister8: return "square.stack.3d.up.fill"
        }
    }
}

@Model
final class PurchaseModel {

    @Attribute(.unique) var id: String
    var kindRaw: String
    var quantity: Int
    var price: Double
    var date: Date
    var stickerCount: Int

    init(kind: PurchaseKind, quantity: Int, price: Double, date: Date = Date()) {
        self.id = UUID().uuidString
        self.kindRaw = kind.rawValue
        self.quantity = quantity
        self.price = price
        self.date = date
        self.stickerCount = kind.stickersPerUnit * quantity
    }

    var kind: PurchaseKind {
        PurchaseKind(rawValue: kindRaw) ?? .pack
    }

    var totalCost: Double { Double(quantity) * price }
}
