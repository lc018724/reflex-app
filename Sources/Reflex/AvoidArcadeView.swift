import SwiftUI
import UIKit
import AudioToolbox

// MARK: - Avoid Arcade Game
// Danger balls bounce around the screen. Gold rings appear as targets.
// Tap a ring before it expires = +1 score. Tap a danger ball = -1 life.
// More balls + faster rings each level.

@MainActor
final class AvoidGame: ObservableObject {
    struct Ring: Identifiable {
        let id = UUID()
        var position: CGPoint
        var expiresAt: Date
        var scale: CGFloat = 0.0
    }

    struct DangerBall: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGPoint
        let radius: CGFloat = 22
    }

    @Published var score: Int = 0
    @Published var lives: Int = 3
    @Published var level: Int = 1
    @Published var combo: Int = 0
    @Published var rings: [Ring] = []
    @Published var balls: [DangerBall] = []
    @Published var isGameOver: Bool = false

    private var fieldSize: CGSize = .zero
    private var spawnTask: Task<Void, Never>?
    private var physicsTask: Task<Void, Never>?
    private var decayTasks: [UUID: Task<Void, Never>] = [:]

    func start(in size: CGSize) {
        fieldSize = size
        isGameOver = false
        score = 0; lives = 3; level = 1; combo = 0
        rings = []; balls = []; decayTasks = [:]
        spawnInitialBalls()
        startSpawnLoop()
        startPhysicsLoop()
    }

    func stop() {
        spawnTask?.cancel(); spawnTask = nil
        physicsTask?.cancel(); physicsTask = nil
        decayTasks.values.forEach { $0.cancel() }
        decayTasks = [:]
    }

    private func spawnInitialBalls() {
        let count = min(3, 1 + level / 3)
        balls = (0..<count).map { _ in makeBall() }
    }

    private func makeBall() -> DangerBall {
        let x = CGFloat.random(in: 40...(fieldSize.width - 40))
        let y = CGFloat.random(in: 40...(fieldSize.height - 40))
        let speed = 80 + CGFloat(level) * 15
        let angle = CGFloat.random(in: 0...(2 * .pi))
        return DangerBall(
            position: CGPoint(x: x, y: y),
            velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed)
        )
    }

    private func startPhysicsLoop() {
        physicsTask = Task { [weak self] in
            var lastTime = Date()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_000_000) // ~60fps
                let now = Date()
                let dt = now.timeIntervalSince(lastTime)
                lastTime = now
                guard let self else { return }
                self.updatePhysics(dt: dt)
            }
        }
    }

    private func updatePhysics(dt: TimeInterval) {
        guard !isGameOver else { return }
        let w = fieldSize.width; let h = fieldSize.height
        let dtF = CGFloat(dt)
        balls = balls.map { var b = $0
            b.position.x += b.velocity.x * dtF
            b.position.y += b.velocity.y * dtF
            if b.position.x < b.radius || b.position.x > w - b.radius {
                b.velocity.x *= -1
                b.position.x = b.position.x < b.radius ? b.radius : w - b.radius
            }
            if b.position.y < b.radius || b.position.y > h - b.radius {
                b.velocity.y *= -1
                b.position.y = b.position.y < b.radius ? b.radius : h - b.radius
            }
            return b
        }
    }

    private func startSpawnLoop() {
        spawnTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, !self.isGameOver else { break }
                let interval = max(1.0, 2.5 - Double(self.level) * 0.1)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled, !self.isGameOver else { break }
                self.spawnRing()
                // Level up every 8 points
                let newLevel = max(1, 1 + self.score / 8)
                if newLevel != self.level {
                    self.level = newLevel
                    // Add a ball if needed
                    let needed = min(4, 1 + self.level / 3)
                    while self.balls.count < needed {
                        self.balls.append(self.makeBall())
                    }
                    // Speed up existing balls
                    let speedMult = 1.0 + CGFloat(self.level - 1) * 0.1
                    self.balls = self.balls.map { var b = $0
                        let currentSpeed = sqrt(b.velocity.x * b.velocity.x + b.velocity.y * b.velocity.y)
                        let targetSpeed = (80 + CGFloat(self.level) * 15) * speedMult
                        let scale = targetSpeed / max(currentSpeed, 1)
                        b.velocity.x *= scale; b.velocity.y *= scale
                        return b
                    }
                }
            }
        }
    }

    private func spawnRing() {
        guard fieldSize != .zero else { return }
        // Pick a position far from all danger balls
        var pos = CGPoint.zero
        for _ in 0..<10 {
            let x = CGFloat.random(in: 60...(fieldSize.width - 60))
            let y = CGFloat.random(in: 60...(fieldSize.height - 60))
            let candidate = CGPoint(x: x, y: y)
            let minDist = balls.map { dist($0.position, candidate) }.min() ?? 999
            if minDist > 80 { pos = candidate; break }
            pos = candidate
        }
        let lifetime = max(0.8, 2.0 - Double(level) * 0.06)
        let ring = Ring(position: pos, expiresAt: Date().addingTimeInterval(lifetime))
        rings.append(ring)
        let ringID = ring.id
        let lifetimeNS = UInt64(lifetime * 1_000_000_000)
        decayTasks[ringID] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: lifetimeNS)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                if let idx = self.rings.firstIndex(where: { $0.id == ringID }) {
                    self.rings.remove(at: idx)
                    self.combo = 0
                }
            }
        }
    }

    func tapRing(id: UUID) {
        guard let idx = rings.firstIndex(where: { $0.id == id }) else { return }
        decayTasks[id]?.cancel(); decayTasks[id] = nil
        rings.remove(at: idx)
        combo += 1
        score += combo
        if UserDefaults.standard.bool(forKey: "hapticsEnabled") {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        if UserDefaults.standard.object(forKey: "soundEnabled") == nil || UserDefaults.standard.bool(forKey: "soundEnabled") { AudioServicesPlaySystemSound(1104) }
    }

    func tapDangerBall() {
        combo = 0
        lives -= 1
        if UserDefaults.standard.bool(forKey: "hapticsEnabled") {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        if UserDefaults.standard.object(forKey: "soundEnabled") == nil || UserDefaults.standard.bool(forKey: "soundEnabled") { AudioServicesPlaySystemSound(1053) }
        if lives <= 0 { gameOver() }
    }

    private func gameOver() {
        stop()
        isGameOver = true
        let key = "avoidArcade_highScore"
        let prev = UserDefaults.standard.integer(forKey: key)
        if score > prev { UserDefaults.standard.set(score, forKey: key) }
    }

    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }
}

// MARK: - Main View

struct AvoidArcadeView: View {
    let onDismiss: () -> Void

    @StateObject private var game = AvoidGame()
    @State private var showGameOver = false
    @State private var shakeOffset: CGFloat = 0
    @State private var prevLives: Int = 3

    var body: some View {
        ZStack {
            RTheme.bg.ignoresSafeArea()

            if showGameOver {
                gameOverOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                VStack(spacing: 0) {
                    topBar.padding(.bottom, 8)
                    statsRow.padding(.bottom, 4)
                    gameField
                }
                .offset(x: shakeOffset)
            }
        }
        .onChange(of: game.lives) { _, newLives in
            if newLives < prevLives { shakeScreen() }
            prevLives = newLives
        }
        .onChange(of: game.isGameOver) { _, over in
            if over {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showGameOver = true }
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { game.stop(); onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(RTheme.muted)
                    .frame(width: 34, height: 34)
                    .background(RTheme.surface)
                    .clipShape(Circle())
            }
            Spacer()
            Text("AVOID")
                .font(RTheme.mono(16, weight: .black))
                .foregroundStyle(RTheme.white)
                .tracking(4)
            Spacer()
            Circle().fill(.clear).frame(width: 34, height: 34)
        }
        .padding(.horizontal, RTheme.pad)
        .padding(.top, 8)
    }

    private var statsRow: some View {
        HStack(spacing: 20) {
            VStack(spacing: 2) {
                Text("\(game.score)")
                    .font(RTheme.mono(28, weight: .black))
                    .foregroundStyle(RTheme.gold)
                    .contentTransition(.numericText())
                Text("SCORE").font(RTheme.mono(9)).foregroundStyle(RTheme.muted).tracking(2)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("LVL \(game.level)")
                    .font(RTheme.mono(16, weight: .bold))
                    .foregroundStyle(RTheme.white)
                Text("LEVEL").font(RTheme.mono(9)).foregroundStyle(RTheme.muted).tracking(2)
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < game.lives ? "heart.fill" : "heart")
                        .foregroundStyle(i < game.lives ? RTheme.red : RTheme.faint)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, RTheme.pad)
    }

    private var gameField: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // Danger balls
                ForEach(game.balls) { ball in
                    Circle()
                        .fill(RTheme.red.opacity(0.85))
                        .frame(width: ball.radius * 2, height: ball.radius * 2)
                        .overlay(
                            Circle().stroke(RTheme.red, lineWidth: 2)
                        )
                        .shadow(color: RTheme.red.opacity(0.5), radius: 8)
                        .position(ball.position)
                        .onTapGesture { game.tapDangerBall() }
                }

                // Rings (targets)
                ForEach(game.rings) { ring in
                    RingTargetView(ring: ring) {
                        game.tapRing(id: ring.id)
                    }
                    .position(ring.position)
                }

                // Combo badge
                if game.combo >= 2 {
                    VStack {
                        HStack {
                            Spacer()
                            Text("x\(game.combo) COMBO")
                                .font(RTheme.mono(11, weight: .black))
                                .foregroundStyle(RTheme.gold)
                                .tracking(2)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(RTheme.gold.opacity(0.12))
                                .clipShape(Capsule())
                                .padding(.trailing, RTheme.pad)
                        }
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
            .onAppear { game.start(in: size) }
            .onDisappear { game.stop() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Game over

    private var gameOverOverlay: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("GAME OVER")
                .font(RTheme.mono(28, weight: .black))
                .foregroundStyle(RTheme.white)
                .tracking(6)
            VStack(spacing: 6) {
                Text("\(game.score)")
                    .font(RTheme.mono(72, weight: .black))
                    .foregroundStyle(RTheme.gold)
                Text("SCORE")
                    .font(RTheme.mono(11))
                    .foregroundStyle(RTheme.muted)
                    .tracking(4)
            }
            let best = UserDefaults.standard.integer(forKey: "avoidArcade_highScore")
            if game.score >= best && game.score > 0 {
                Text("NEW HIGH SCORE")
                    .font(RTheme.mono(12, weight: .black))
                    .foregroundStyle(RTheme.gold)
                    .tracking(3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(RTheme.gold.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(RTheme.gold.opacity(0.4), lineWidth: 1))
            }
            Spacer()
            VStack(spacing: 12) {
                GoldButton(label: "PLAY AGAIN", action: {
                    withAnimation { showGameOver = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        prevLives = 3
                    }
                }, fullWidth: true)
                Button("BACK TO MENU") { game.stop(); onDismiss() }
                    .font(RTheme.mono(13))
                    .foregroundStyle(RTheme.muted)
            }
            .padding(.horizontal, RTheme.pad)
            .padding(.bottom, 40)
        }
    }

    private func shakeScreen() {
        let shakes: [CGFloat] = [-12, 12, -9, 9, -5, 5, 0]
        var delay = 0.0
        for val in shakes {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 0.05)) { shakeOffset = val }
            }
            delay += 0.055
        }
    }
}

// MARK: - Ring Target View

struct RingTargetView: View {
    let ring: AvoidGame.Ring
    let onTap: () -> Void

    @State private var scale: CGFloat = 0.1
    @State private var progress: CGFloat = 1.0
    private let size: CGFloat = 54

    var body: some View {
        ZStack {
            // Decay ring
            Circle()
                .stroke(RTheme.gold.opacity(0.25), lineWidth: 4)
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(RTheme.gold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: ring.expiresAt.timeIntervalSinceNow), value: progress)

            // Inner target
            Circle()
                .fill(RTheme.gold.opacity(0.15))
                .frame(width: size - 12, height: size - 12)
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(RTheme.gold)
        }
        .frame(width: size + 8, height: size + 8)
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) { scale = 1.0 }
            withAnimation(.linear(duration: max(0.1, ring.expiresAt.timeIntervalSinceNow))) {
                progress = 0.0
            }
        }
        .onTapGesture { onTap() }
    }
}
