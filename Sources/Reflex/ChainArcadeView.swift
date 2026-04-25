import SwiftUI
import AudioToolbox

// MARK: - Chain Arcade Game
// Numbered targets appear. Tap them in ascending order as fast as possible.

struct ChainTarget: Identifiable {
    let id = UUID()
    let number: Int
    let position: CGPoint
    var tapped = false
    var lifetime: Double
}

@MainActor
class ChainGame: ObservableObject {
    @Published var targets: [ChainTarget] = []
    @Published var lives = 3
    @Published var score = 0
    @Published var round = 1
    @Published var nextRequired = 1
    @Published var phase: ChainPhase = .idle
    @Published var highScore: Int = 0
    @Published var roundFlash = false

    private let store = TestStore()
    private var decayTask: Task<Void, Never>?

    enum ChainPhase { case idle, playing, dead }

    var targetCount: Int { min(3 + round, 8) }
    var lifetime: Double { max(0.9, 2.2 - Double(round) * 0.07) }

    func start() {
        highScore = UserDefaults.standard.integer(forKey: "chainArcade_highScore")
        score = 0
        lives = 3
        round = 1
        phase = .playing
        spawnRound()
    }

    func spawnRound() {
        decayTask?.cancel()
        let count = targetCount
        let lt = lifetime
        targets = generateTargets(count: count, lifetime: lt)
        nextRequired = 1
        roundFlash = false

        // Decay loop: expire targets that outlive their lifetime
        decayTask = Task {
            let start = Date()
            while !Task.isCancelled && phase == .playing {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { break }
                let elapsed = Date().timeIntervalSince(start)
                let expiredAny = targets.contains { !$0.tapped && elapsed > $0.lifetime }
                if expiredAny {
                    onExpire()
                    break
                }
            }
        }
    }

    func tap(target: ChainTarget) {
        guard phase == .playing else { return }
        if target.number == nextRequired {
            if UserDefaults.standard.object(forKey: "soundEnabled") == nil || UserDefaults.standard.bool(forKey: "soundEnabled") { AudioServicesPlaySystemSound(1104) }
            if let idx = targets.firstIndex(where: { $0.id == target.id }) {
                targets[idx].tapped = true
            }
            score += max(1, 10 - (nextRequired / 2))
            nextRequired += 1
            if nextRequired > targets.count {
                // Round complete
                round += 1
                score += round * 5
                withAnimation(.easeInOut(duration: 0.15)) { roundFlash = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.roundFlash = false
                    self?.spawnRound()
                }
            }
        } else {
            // Wrong tap
            if UserDefaults.standard.object(forKey: "soundEnabled") == nil || UserDefaults.standard.bool(forKey: "soundEnabled") { AudioServicesPlaySystemSound(1107) }
            lives -= 1
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            if lives <= 0 { endGame() }
        }
    }

    private func onExpire() {
        if UserDefaults.standard.object(forKey: "soundEnabled") == nil || UserDefaults.standard.bool(forKey: "soundEnabled") { AudioServicesPlaySystemSound(1107) }
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        lives -= 1
        if lives <= 0 {
            endGame()
        } else {
            // Penalize but continue - show old targets briefly then respawn
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.spawnRound()
            }
        }
    }

    func endGame() {
        decayTask?.cancel()
        phase = .dead
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(score, forKey: "chainArcade_highScore")
        }
    }

    private func generateTargets(count: Int, lifetime: Double) -> [ChainTarget] {
        let margin: CGFloat = 60
        let playW: CGFloat = 300
        let playH: CGFloat = 480
        var positions: [CGPoint] = []
        var result: [ChainTarget] = []

        for i in 1...count {
            var pos: CGPoint
            var tries = 0
            repeat {
                pos = CGPoint(
                    x: CGFloat.random(in: margin...(playW - margin)),
                    y: CGFloat.random(in: margin...(playH - margin))
                )
                tries += 1
            } while positions.contains(where: { dist($0, pos) < 70 }) && tries < 30
            positions.append(pos)
            result.append(ChainTarget(number: i, position: pos, lifetime: lifetime + Double(i) * 0.1))
        }
        return result
    }

    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }
}

// MARK: - Main View

struct ChainArcadeView: View {
    let onDismiss: () -> Void

    @StateObject private var game = ChainGame()
    @State private var shakeOffset: CGFloat = 0
    @State private var prevLives = 3

    var body: some View {
        ZStack {
            (game.roundFlash ? RTheme.green.opacity(0.12) : RTheme.bg)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.2), value: game.roundFlash)

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(RTheme.muted)
                            .frame(width: 36, height: 36)
                            .background(RTheme.surface)
                            .clipShape(Circle())
                    }

                    Spacer()

                    VStack(spacing: 1) {
                        Text("CHAIN")
                            .font(RTheme.mono(10, weight: .bold))
                            .foregroundStyle(RTheme.muted)
                            .tracking(4)
                        Text("\(game.score)")
                            .font(RTheme.mono(22, weight: .black))
                            .foregroundStyle(RTheme.white)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3), value: game.score)
                    }

                    Spacer()

                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < game.lives ? "heart.fill" : "heart")
                                .font(.system(size: 14))
                                .foregroundStyle(i < game.lives ? RTheme.red : RTheme.faint)
                                .animation(.spring(response: 0.3), value: game.lives)
                        }
                    }
                    .frame(width: 60)
                }
                .padding(.horizontal, RTheme.pad)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Round + next required indicator
                if game.phase == .playing {
                    HStack(spacing: 16) {
                        Text("ROUND \(game.round)")
                            .font(RTheme.mono(9, weight: .bold))
                            .foregroundStyle(RTheme.muted)
                            .tracking(3)
                        Spacer()
                        HStack(spacing: 6) {
                            Text("NEXT")
                                .font(RTheme.mono(9))
                                .foregroundStyle(RTheme.faint)
                                .tracking(2)
                            Text("\(game.nextRequired)")
                                .font(RTheme.mono(18, weight: .black))
                                .foregroundStyle(RTheme.gold)
                                .animation(.spring(response: 0.2), value: game.nextRequired)
                        }
                    }
                    .padding(.horizontal, RTheme.pad)
                    .padding(.bottom, 4)
                }

                // Play field
                ZStack {
                    if game.phase == .idle {
                        idleScreen
                    } else if game.phase == .dead {
                        deathScreen
                    } else {
                        playField
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(x: shakeOffset)
                .onChange(of: game.lives) { _, newVal in
                    if newVal < prevLives { shakeScreen() }
                    prevLives = newVal
                }
            }
        }
        .onAppear { game.start() }
    }

    // MARK: - Sub-views

    private var playField: some View {
        GeometryReader { geo in
            ZStack {
                // Connector lines between unvisited sequential targets
                Canvas { context, size in
                    let untapped = game.targets
                        .filter { !$0.tapped }
                        .sorted { $0.number < $1.number }
                    guard untapped.count >= 2 else { return }
                    let scale = CGPoint(x: size.width / 300, y: size.height / 480)
                    for i in 0..<(untapped.count - 1) {
                        let a = CGPoint(x: untapped[i].position.x * scale.x,
                                        y: untapped[i].position.y * scale.y)
                        let b = CGPoint(x: untapped[i+1].position.x * scale.x,
                                        y: untapped[i+1].position.y * scale.y)
                        var path = Path()
                        path.move(to: a)
                        path.addLine(to: b)
                        context.stroke(path, with: .color(RTheme.faint.opacity(0.35)),
                                       style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    }
                }

                ForEach(game.targets) { target in
                    if !target.tapped {
                        ChainTargetView(
                            target: target,
                            isNext: target.number == game.nextRequired,
                            totalTargets: game.targets.count
                        )
                        .position(
                            x: target.position.x * geo.size.width / 300,
                            y: target.position.y * geo.size.height / 480
                        )
                        .onTapGesture { game.tap(target: target) }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var idleScreen: some View {
        VStack(spacing: 24) {
            Text("⛓️").font(.system(size: 64))
            Text("CHAIN")
                .font(RTheme.serif(36, weight: .black))
                .foregroundStyle(RTheme.gold)
                .tracking(6)
            Text("Tap targets in order")
                .font(RTheme.mono(14))
                .foregroundStyle(RTheme.muted)
            GoldButton(label: "START", action: { game.start() }, fullWidth: false)
        }
    }

    private var deathScreen: some View {
        VStack(spacing: 20) {
            Text("GAME OVER")
                .font(RTheme.serif(28, weight: .black))
                .foregroundStyle(RTheme.red)
                .tracking(4)

            VStack(spacing: 8) {
                Text("\(game.score)")
                    .font(RTheme.mono(64, weight: .black))
                    .foregroundStyle(RTheme.white)
                Text("SCORE")
                    .font(RTheme.mono(9))
                    .foregroundStyle(RTheme.faint)
                    .tracking(4)
            }

            if game.score >= game.highScore && game.highScore > 0 {
                Text("NEW HIGH SCORE!")
                    .font(RTheme.mono(11, weight: .bold))
                    .foregroundStyle(RTheme.gold)
                    .tracking(3)
                    .transition(.scale)
            } else {
                Text("BEST: \(game.highScore)")
                    .font(RTheme.mono(11))
                    .foregroundStyle(RTheme.muted)
                    .tracking(2)
            }

            HStack(spacing: 16) {
                GoldButton(label: "PLAY AGAIN", action: { game.start() }, fullWidth: false)
                Button(action: onDismiss) {
                    Text("HOME")
                        .font(RTheme.mono(13, weight: .bold))
                        .foregroundStyle(RTheme.muted)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(RTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.spring(response: 0.4), value: game.phase)
    }

    private func shakeScreen() {
        let sequence: [CGFloat] = [8, -7, 6, -5, 3, -2, 0]
        for (i, offset) in sequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                withAnimation(.easeInOut(duration: 0.04)) { shakeOffset = offset }
            }
        }
    }
}

// MARK: - Chain Target View

struct ChainTargetView: View {
    let target: ChainTarget
    let isNext: Bool
    let totalTargets: Int

    @State private var appeared = false
    @State private var timeLeft: Double = 1.0
    @State private var decayTimer: Timer?

    var body: some View {
        ZStack {
            // Decay ring
            Circle()
                .trim(from: 0, to: timeLeft)
                .stroke(isNext ? RTheme.gold : RTheme.faint.opacity(0.5), lineWidth: 3)
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.2), value: timeLeft)

            Circle()
                .fill(isNext ? RTheme.gold.opacity(0.18) : RTheme.surface)
                .frame(width: 46, height: 46)
                .overlay(
                    Circle()
                        .stroke(isNext ? RTheme.gold : RTheme.faint, lineWidth: 1.5)
                )

            Text("\(target.number)")
                .font(RTheme.mono(isNext ? 18 : 15, weight: .black))
                .foregroundStyle(isNext ? RTheme.gold : RTheme.white.opacity(0.7))
        }
        .scaleEffect(appeared ? (isNext ? 1.1 : 1.0) : 0.01)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: appeared)
        .animation(.spring(response: 0.2), value: isNext)
        .onAppear {
            appeared = true
            timeLeft = 1.0
            decayTimer = Timer.scheduledTimer(withTimeInterval: target.lifetime / 50, repeats: true) { _ in
                DispatchQueue.main.async {
                    timeLeft = max(0, timeLeft - 0.02)
                    if timeLeft <= 0 { decayTimer?.invalidate() }
                }
            }
        }
        .onDisappear {
            decayTimer?.invalidate()
        }
    }
}
