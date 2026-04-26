import SwiftUI

// MARK: - Simple Confetti Burst
// Canvas-based confetti particles that fall from top when triggered.

struct ConfettiView: View {
    @Binding var isActive: Bool

    @State private var particles: [Particle] = []
    @State private var displayLink: Timer?

    private let colors: [Color] = [
        .init(red: 0.0, green: 0.48, blue: 1.0),
        .init(red: 0.27, green: 0.91, blue: 0.55), // green
        .init(red: 1, green: 0.27, blue: 0.27),    // red
        .init(red: 0.55, green: 0.35, blue: 0.95), // purple
        .white
    ]

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var rotation: Double
        var rotationSpeed: Double
        var color: Color
        var width: CGFloat
        var height: CGFloat
        var opacity: Double
    }

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                for p in particles {
                    ctx.opacity = p.opacity
                    ctx.translateBy(x: p.x, y: p.y)
                    ctx.rotate(by: .degrees(p.rotation))
                    ctx.fill(Path(CGRect(x: -p.width / 2, y: -p.height / 2, width: p.width, height: p.height)),
                             with: .color(p.color))
                    ctx.translateBy(x: -p.x, y: -p.y)
                    ctx.rotate(by: .degrees(-p.rotation))
                }
            }
            .allowsHitTesting(false)
            .onChange(of: isActive) { _, active in
                if active {
                    spawnParticles(in: geo.size)
                }
            }
        }
    }

    private func spawnParticles(in size: CGSize) {
        particles = (0..<80).map { _ in
            Particle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: -50...(-10)),
                vx: CGFloat.random(in: -80...80),
                vy: CGFloat.random(in: 200...500),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -180...180),
                color: colors.randomElement()!,
                width: CGFloat.random(in: 6...12),
                height: CGFloat.random(in: 4...8),
                opacity: 1.0
            )
        }
        displayLink?.invalidate()
        var elapsed: Double = 0
        let dt: Double = 1.0 / 60.0
        displayLink = Timer.scheduledTimer(withTimeInterval: dt, repeats: true) { timer in
            elapsed += dt
            particles = particles.compactMap { var p = $0
                p.x += p.vx * dt
                p.y += p.vy * dt
                p.vy += 200 * dt  // gravity
                p.rotation += p.rotationSpeed * dt
                p.opacity = max(0, 1.0 - elapsed / 2.5)
                if p.y > UIScreen.main.bounds.height + 50 || p.opacity <= 0 { return nil }
                return p
            }
            if particles.isEmpty || elapsed > 3.0 {
                timer.invalidate()
                displayLink = nil
                isActive = false
            }
        }
    }
}
