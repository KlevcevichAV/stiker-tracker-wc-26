import SwiftUI

/// Полноэкранный overlay с баннером разблокировки достижения и конфетти.
/// Добавляется в корень AlbumView через .overlay.
struct AchievementBannerOverlay: View {

    let definition: AchievementDefinition
    let onDismiss: () -> Void

    @Environment(\.appLanguage) private var language

    @State private var slideIn  = false
    @State private var opacity  = 0.0
    @State private var badgeScale: CGFloat = 0.5

    private var isRu: Bool { language.isRussian }

    var body: some View {
        ZStack(alignment: .top) {
            // Полупрозрачное затемнение — тап закрывает
            Color.black.opacity(opacity * 0.35)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Конфетти поверх всего
            ConfettiView()
                .ignoresSafeArea()
                .opacity(opacity)

            // Сам баннер
            bannerCard
                .padding(.top, 60)
                .offset(y: slideIn ? 0 : -260)
                .opacity(opacity)
        }
        .onAppear { animateIn() }
    }

    // MARK: - Banner card

    private var bannerCard: some View {
        VStack(spacing: 14) {
            // "Новое достижение!"
            Text(isRu ? "🏅 Новое достижение!" : "🏅 Achievement Unlocked!")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .textCase(.uppercase)
                .tracking(1.5)

            // Иконка
            ZStack {
                Circle()
                    .fill(iconGradient)
                    .frame(width: 64, height: 64)
                    .shadow(color: iconColor.opacity(0.5), radius: 12)

                Image(systemName: definition.icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(badgeScale)
            .animation(
                .interpolatingSpring(stiffness: 200, damping: 12).delay(0.2),
                value: badgeScale
            )

            // Название
            Text(definition.localizedTitle(isRu: isRu))
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            // Описание
            Text(definition.localizedDesc(isRu: isRu))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)

            // Категория-бейдж
            Text(definition.category.localizedTitle(isRu: isRu).uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(iconColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(iconColor.opacity(0.15), in: Capsule())
                .overlay(Capsule().strokeBorder(iconColor.opacity(0.4), lineWidth: 1))
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .background(bannerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 24, y: 8)
        .padding(.horizontal, 24)
    }

    // MARK: - Animations

    private func animateIn() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            slideIn = true
            opacity = 1.0
        }
        withAnimation(.interpolatingSpring(stiffness: 200, damping: 12).delay(0.15)) {
            badgeScale = 1.0
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.3)) {
            slideIn = false
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onDismiss() }
    }

    // MARK: - Style

    private var iconColor: Color {
        switch definition.category {
        case .superstar:   return .yellow
        case .starHunter:  return .orange
        case .team:        return .green
        case .worldRuler:  return .purple
        case .centurion:   return .blue
        case .milestone:   return .cyan
        }
    }

    private var iconGradient: LinearGradient {
        LinearGradient(
            colors: [iconColor.opacity(0.7), iconColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var bannerBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.10, blue: 0.18),
                Color(red: 0.06, green: 0.06, blue: 0.12),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
