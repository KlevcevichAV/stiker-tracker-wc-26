import SwiftUI
import SwiftData

struct AddPurchaseView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.appLanguage)  private var language

    private var isRu: Bool { language.isRussian }

    // nil → создание, non-nil → редактирование
    private let existing: PurchaseModel?

    @State private var kind: PurchaseKind
    @State private var quantity: Int
    @State private var priceText: String
    @State private var date: Date

    // Вычисляется реактивно из kind + quantity
    private var stickerCount: Int { kind.stickersPerUnit * quantity }

    init() {
        existing = nil
        let defaultKind = PurchaseKind.pack
        _kind       = State(initialValue: defaultKind)
        _quantity   = State(initialValue: 1)
        _priceText  = State(initialValue: defaultKind.defaultPrice.map { formatPrice($0) } ?? "")
        _date       = State(initialValue: Date())
    }

    init(purchase: PurchaseModel) {
        existing    = purchase
        _kind       = State(initialValue: purchase.kind)
        _quantity   = State(initialValue: purchase.quantity)
        _priceText  = State(initialValue: formatPrice(purchase.price))
        _date       = State(initialValue: purchase.date)
    }

    private var parsedPrice: Double { Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var canSave: Bool { quantity > 0 && parsedPrice > 0 }

    var body: some View {
        NavigationStack {
            Form {
                // Вид
                Section {
                    Picker(isRu ? "Вид" : "Type", selection: $kind) {
                        ForEach(PurchaseKind.allCases, id: \.self) { k in
                            Label(isRu ? k.nameRU : k.nameEN, systemImage: k.icon)
                                .tag(k)
                        }
                    }
                    .onChange(of: kind) { _, newKind in
                        if let def = newKind.defaultPrice {
                            priceText = formatPrice(def)
                        }
                    }
                }

                // Кол-во + цена
                Section {
                    Stepper(value: $quantity, in: 1...999) {
                        HStack {
                            Text(isRu ? "Количество" : "Quantity")
                            Spacer()
                            Text("\(quantity)")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text(isRu ? "Цена за ед." : "Price each")
                        Spacer()
                        TextField("0.00", text: $priceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                            .font(.system(size: 15, design: .rounded))
                    }
                }

                // Дата
                Section {
                    DatePicker(
                        isRu ? "Дата" : "Date",
                        selection: $date,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }

                // Итого наклеек (read-only)
                Section {
                    HStack {
                        Label(
                            isRu ? "Наклеек" : "Stickers",
                            systemImage: "square.on.square.fill"
                        )
                        .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(stickerCount)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(stickerCount > 0 ? .orange : .secondary)
                    }

                    HStack {
                        Label(
                            isRu ? "Сумма" : "Total",
                            systemImage: "banknote"
                        )
                        .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatPrice(parsedPrice * Double(quantity)))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                    }
                } header: {
                    Text(isRu ? "Итог" : "Summary")
                }
            }
            .navigationTitle(existing == nil
                ? (isRu ? "Новая покупка" : "New Purchase")
                : (isRu ? "Редактировать" : "Edit Purchase"))
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
            ex.kindRaw      = kind.rawValue
            ex.quantity     = quantity
            ex.price        = parsedPrice
            ex.date         = date
            ex.stickerCount = stickerCount
            try? context.save()
        } else {
            let p = PurchaseModel(kind: kind, quantity: quantity, price: parsedPrice, date: date)
            context.insert(p)
            try? context.save()
            SheetsService.sendPurchase(
                kind: isRu ? kind.nameRU : kind.nameEN,
                quantity: quantity,
                price: parsedPrice,
                totalCost: parsedPrice * Double(quantity),
                stickerCount: stickerCount
            )
        }
        dismiss()
    }
}

private func formatPrice(_ value: Double) -> String {
    let s = String(format: "%.2f", value)
    // убираем лишние нули: "4.90" → "4.9", "4.00" → "4"... нет, оставляем 2 знака для цен
    return s
}
