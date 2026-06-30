import SwiftData
import Foundation

@Model
final class SaleModel {

    @Attribute(.unique) var id: String
    var price: Double
    var date: Date
    var comment: String

    init(price: Double, date: Date = Date(), comment: String = "") {
        self.id      = UUID().uuidString
        self.price   = price
        self.date    = date
        self.comment = comment
    }
}
