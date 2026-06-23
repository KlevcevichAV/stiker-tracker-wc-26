import SwiftUI
import SwiftData

struct StickerCell: View {

    let sticker: StickerModel
    @Environment(\.modelContext)        private var context
    @Environment(\.achievementsManager) private var achievements
    @Environment(\.appLanguage)         private var language

    @Query(filter: #Predicate<ExchangeModel> { $0.statusRaw == "active" })
    private var activeExchanges: [ExchangeModel]

    private var reservedCount: Int {
        ExchangeService.reservedCount(for: sticker.id, in: activeExchanges)
    }

    private var incomingCount: Int {
        ExchangeService.incomingCount(for: sticker.id, in: activeExchanges)
    }

    // Анимационное состояние «примагничивания»
    @State private var snapScale: CGFloat = 1.0
    @State private var snapOffset: CGSize = .zero
    @State private var isGlowing = false
    @State private var foilPhase: CGFloat = 0   // анимация переливания foil

    // Управление диалогами
    @State private var showPasteConfirm = false
    @State private var showPastedActions = false

    private var localizedName: String {
        language.isRussian ? sticker.nameRU : sticker.nameEN
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(cellBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(borderColor, lineWidth: borderWidth)
                    )
                    // Свечение при вклеивании
                    .shadow(
                        color: glowColor.opacity(isGlowing ? 0.6 : 0.08),
                        radius: isGlowing ? 8 : 2,
                        x: 0, y: 0
                    )

                cellContent
            }
            .aspectRatio(0.72, contentMode: .fit)
            // Анимация примагничивания: наклейка «прилетает» на место
            .scaleEffect(snapScale)
            .offset(snapOffset)
            .animation(.interpolatingSpring(stiffness: 280, damping: 18), value: snapScale)
            .animation(.interpolatingSpring(stiffness: 280, damping: 18), value: snapOffset)
            // Foil: переливающийся градиент поверх карточки
            .overlay(foilOverlay)
            .onTapGesture(perform: handleDoubleTap)
            .onAppear {
                guard sticker.isFoil else { return }
                withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: true)) {
                    foilPhase = 1
                }
            }

            Text(sticker.id)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        // ── Диалог для ПУСТОЙ наклейки ──────────────────────────────────
        .confirmationDialog(
            pasteDialogTitle,
            isPresented: $showPasteConfirm,
            titleVisibility: .visible
        ) {
            Button(isRu ? "Вклеить" : "Paste") {
                triggerSnapAnimation()
                StickerInteractionService.paste(sticker, context: context, achievements: achievements)
            }
            Button(isRu ? "Отмена" : "Cancel", role: .cancel) {}
        } message: {
            Text(sticker.id)
        }
        // ── Диалог для ВКЛЕЕННОЙ / ПОВТОРКИ ─────────────────────────────
        .confirmationDialog(
            pastedDialogTitle,
            isPresented: $showPastedActions,
            titleVisibility: .visible
        ) {
            Button(duplicateButtonTitle) {
                StickerInteractionService.addDuplicate(sticker, context: context, achievements: achievements)
            }
            Button(
                isRu ? "Убрать наклейку" : "Remove sticker",
                role: .destructive
            ) {
                StickerInteractionService.remove(sticker, context: context, achievements: achievements)
            }
            Button(isRu ? "Отмена" : "Cancel", role: .cancel) {}
        } message: {
            if sticker.status == .duplicate {
                Text(isRu
                     ? "Повторок: \(sticker.duplicateCount)"
                     : "Duplicates: \(sticker.duplicateCount)")
            }
        }
    }

    // MARK: - Gesture handler

    private func handleDoubleTap() {
        switch sticker.status {
        case .missing:
            showPasteConfirm = true
        case .pasted, .duplicate:
            showPastedActions = true
        }
    }

    // MARK: - Snap animation

    /// Наклейка «вылетает» из позиции над страницей и притягивается на место.
    private func triggerSnapAnimation() {
        // Начальное положение — чуть сверху и со скейлом «в воздухе»
        snapScale  = 1.25
        snapOffset = CGSize(width: 0, height: -18)
        isGlowing  = true

        // Небольшая задержка, затем примагничиваем
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            snapScale  = 1.0
            snapOffset = .zero

            // Гашение свечения
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isGlowing = false
            }
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var cellContent: some View {
        switch sticker.status {
        case .missing:    missingContent
        case .pasted:     pastedContent
        case .duplicate:  duplicateContent
        }
    }

    private var missingContent: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 3) {
                Image(systemName: typeIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                Text(localizedName)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 4)
            }

            if incomingCount > 0 {
                Text("⇄")
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.teal, in: RoundedRectangle(cornerRadius: 4))
                    .padding(3)
            }
        }
    }

    private var pastedContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(pastedGradient)
            VStack(spacing: 3) {
                Image(systemName: typeIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
                Text(localizedName)
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var duplicateContent: some View {
        ZStack(alignment: .topTrailing) {
            pastedContent

            VStack(spacing: 2) {
                Text(sticker.duplicateCount > 1 ? "×\(sticker.duplicateCount + 1)" : "×2")
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 4))

                if reservedCount > 0 {
                    Text("⇄\(reservedCount)")
                        .font(.system(size: 7, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.teal, in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(3)
        }
    }

    // MARK: - Foil overlay

    @ViewBuilder
    private var foilOverlay: some View {
        if sticker.isFoil {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear,                              location: 0),
                            .init(color: .white.opacity(0.08),                location: foilPhase * 0.3),
                            .init(color: Color(hue: 0.55 + foilPhase * 0.35,
                                               saturation: 0.9,
                                               brightness: 1).opacity(0.25), location: foilPhase * 0.55),
                            .init(color: Color(hue: 0.85 + foilPhase * 0.15,
                                               saturation: 1,
                                               brightness: 1).opacity(0.20), location: foilPhase * 0.75),
                            .init(color: .white.opacity(0.06),                location: foilPhase * 0.9),
                            .init(color: .clear,                              location: 1),
                        ],
                        startPoint: UnitPoint(x: foilPhase * 0.8, y: 0),
                        endPoint:   UnitPoint(x: 1 - foilPhase * 0.8, y: 1)
                    )
                )
                .allowsHitTesting(false)
                // Золотая рамка для foil-карточек
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.yellow.opacity(0.9), .orange.opacity(0.6),
                                         .yellow.opacity(0.4), .white.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint:   .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        }
    }

    // MARK: - Style helpers

    private var cellBackground: Color {
        sticker.status == .missing ? Color(.systemGray6) : .clear
    }

    private var borderColor: Color {
        sticker.status == .missing ? Color(.systemGray4) : .clear
    }

    private var borderWidth: CGFloat {
        sticker.status == .missing ? 1 : 0
    }

    private var glowColor: Color {
        switch sticker.type {
        case .logo:      return .orange
        case .teamPhoto: return .purple
        case .player:    return .blue
        }
    }

    private var pastedGradient: LinearGradient {
        LinearGradient(
            colors: [glowColor.opacity(0.85), glowColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var typeIcon: String {
        switch sticker.type {
        case .logo:      return "shield.fill"
        case .teamPhoto: return "person.3.fill"
        case .player:    return "person.fill"
        }
    }

    // MARK: - Dialog strings

    private var isRu: Bool { language.isRussian }

    private var pasteDialogTitle: String {
        isRu ? "Вклеить наклейку?" : "Paste sticker?"
    }

    private var pastedDialogTitle: String {
        isRu ? "Эта наклейка уже вклеена" : "Sticker already pasted"
    }

    private var duplicateButtonTitle: String {
        sticker.status == .duplicate
            ? (isRu ? "Ещё одна повторка (+1)" : "Add another duplicate (+1)")
            : (isRu ? "Добавить в повторки" : "Add to duplicates")
    }
}
