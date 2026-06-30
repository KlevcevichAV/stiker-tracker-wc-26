import SwiftUI
import SwiftData

struct AddSaleView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.appLanguage)  private var language

    private var isRu: Bool { language.isRussian }

    private let existing: SaleModel?

    @State private var priceText: String
    @State private var date: Date
    @State private var comment: String

    init() {
        existing   = nil
        _priceText = State(initialValue: "")
        _date      = State(initialValue: Date())
        _comment   = State(initialValue: "")
    }

    init(sale: SaleModel) {
        existing   = sale
        _priceText = State(initialValue: formatSalePrice(sale.price))
        _date      = State(initialValue: sale.date)
        _comment   = State(initialValue: sale.comment)
    }

    private var parsedPrice: Double { Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var canSave: Bool { parsedPrice > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(isRu ? "Цена" : "Price")
                        Spacer()
                        TextField("0.00", text: $priceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .font(.system(size: 15, design: .rounded))
                    }

                    DatePicker(
                        isRu ? "Дата" : "Date",
                        selection: $date,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }

                Section(header: Text(isRu ? "Комментарий" : "Comment")) {
                    TextField(
                        isRu ? "Что именно продал..." : "What was sold...",
                        text: $comment,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }
            }
            .navigationTitle(existing == nil
                ? (isRu ? "Новая продажа" : "New Sale")
                : (isRu ? "Редактировать" : "Edit Sale"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isRu ? "Отмена" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isRu ? "Сохранить" : "Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        if let ex = existing {
            ex.price   = parsedPrice
            ex.date    = date
            ex.comment = comment
            try? context.save()
        } else {
            let s = SaleModel(price: parsedPrice, date: date, comment: comment)
            context.insert(s)
            try? context.save()
        }
        dismiss()
    }
}

private func formatSalePrice(_ value: Double) -> String {
    String(format: "%.2f", value)
}
