import SwiftUI

/// Лёгкая SwiftUI-анимация конфетти из эмодзи-частиц.
/// Запускается один раз при появлении.
struct ConfettiView: View {

    private struct Particle: Identifiable {
        let id = UUID()
        let symbol: String
        let x: CGFloat          // стартовая горизонталь (0…1 от ширины)
        let delay: Double
        let duration: Double
        let size: CGFloat
        let rotationDeg: Double
        let color: Color
    }

    private let symbols = ["⭐️","🌟","✨","🎉","🏆","🥇","⚽️","🎊"]
    private let colors: [Color] = [.yellow, .orange, .red, .green, .blue, .purple, .pink]

    @State private var particles: [Particle] = []
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Text(p.symbol)
                        .font(.system(size: p.size))
                        .foregroundStyle(p.color)
                        .position(
                            x: p.x * geo.size.width,
                            y: animate ? geo.size.height + 40 : -20
                        )
                        .rotationEffect(.degrees(animate ? p.rotationDeg : 0))
                        .opacity(animate ? 0 : 1)
                        .animation(
                            .easeIn(duration: p.duration).delay(p.delay),
                            value: animate
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            particles = (0..<28).map { _ in
                Particle(
                    symbol:       symbols.randomElement()!,
                    x:            CGFloat.random(in: 0.05...0.95),
                    delay:        Double.random(in: 0...0.6),
                    duration:     Double.random(in: 1.2...2.2),
                    size:         CGFloat.random(in: 14...26),
                    rotationDeg:  Double.random(in: -360...360),
                    color:        colors.randomElement()!
                )
            }
            // Небольшая задержка, чтобы SwiftUI успел разместить частицы
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                animate = true
            }
        }
    }
}
