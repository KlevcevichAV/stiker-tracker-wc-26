import SwiftUI

/// Компактный бейдж прогресса для шапки страницы альбома.
/// Отображает «10 / 20  50%» на тёмном фоне корешка.
struct PageProgressBadge: View {

    let stat: ProgressStat

    var body: some View {
        HStack(spacing: 6) {
            // Круговой прогресс
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: stat.percent)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: stat.percent)
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 0) {
                Text(stat.absoluteString)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(stat.percentString)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var ringColor: Color {
        switch stat.percent {
        case 1.0:        return .green
        case 0.5..<1.0:  return .orange
        default:         return .white
        }
    }
}
