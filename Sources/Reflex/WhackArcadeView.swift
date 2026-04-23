import SwiftUI
import UIKit

// MARK: - Whack Arcade
// Targets pop up at random positions. Tap each one before it fades.
// Speed/count increase as score grows. 3 lives.

struct WhackArcadeView: View {
    let onDismiss: () -> Void

    @StateObject private var game = WhackGame()
    @State private var showGameOver = false

    var body: some View {
        ZStack {
            RTheme.bg.ignoresSafeArea()

            if showGameOver {
                whackGameOver
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                VStack(spacing: 0) {
                    whackTopBar
                    whackStatsRow
                    whackField
                        .layoutPriority(1)
                }
            }
        }
        .onChange(of: game.isGameOver) { _, over in
            if over {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showGameOver = true
                }
            }
        }
        .onAppear { game.start() }
        .onDisappear { game.stop() }
    }

    // MARK: - Top bar

    private var whackTopBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RTheme.muted)
                    .frame(width: 36, height: 36)
                    .background(RTheme.surface)
                    .clipShape(Circle())
            }
            Spacer()
            Text("WHACK")
                .font(RTheme.mono(13, weight: .medium))
                .foregroundStyle(RTheme.muted)
                .tracking(4)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, RTheme.pad)
        .padding(.top, 16)
    }

    // MARK: - Stats row

    private var whackStatsRow: some View {
        HStack(spacing: 0) {
            // Lives
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < game.lives ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundStyle(i < game.lives ? RTheme.red : RTheme.faint)
                        .animation(.spring(response: 0.2), value: game.lives)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 2) {
                Text("\(game.score)")
                    .font(RTheme.mono(40, weight: .bold))
                    .foregroundStyle(RTheme.gold)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: game.score)
                Text("SCORE")
                    .font(RTheme.mono(9))
                    .foregroundStyle(RTheme.faint)
                    .tracking(3)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 2) {
                Text("LV \(game.level)")
                    .font(RTheme.mono(22, weight: .bold))
                    .foregroundStyle(levelColor)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: game.level)
                Text("BEST \(game.best)")
                    .font(RTheme.mono(9))
                    .foregroundStyle(RTheme.faint)
                    .tracking(2)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, RTheme.pad)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var levelColor: Color {
        switch game.level {
        case 1: return RTheme.gold
        case 2: return RTheme.green
        case 3...: return RTheme.red
        default: return RTheme.gold
        }
    }

    // MARK: - Play field

    private var whackField: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(game.targets) { target in
                    WhackTargetView(target: target) {
                        game.tapTarget(id: target.id)
                    }
                    .position(x: target.x * geo.size.width,
                               y: target.y * geo.size.height)
                }

                // Floating score popups
                ForEach(game.floatingPoints) { fp in
                    FloatingScoreView(fp: fp)
                        .position(x: fp.x * geo.size.width,
                                   y: fp.y * geo.size.height - 30)
                }

                // Combo banner
                if game.combo >= 5 {
                    comboIndicator
                        .position(x: geo.size.width / 2, y: 22)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 40)
    }

    private var comboIndicator: some View {
        HStack(spacing: 5) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(RTheme.bg)
            Text("x\(game.combo) COMBO")
                .font(RTheme.mono(11, weight: .bold))
                .foregroundStyle(RTheme.bg)
                .tracking(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(RTheme.gold)
        .clipShape(Capsule())
        .shadow(color: RTheme.gold.opacity(0.5), radius: 8)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }

    // MARK: - Game Over

    private var whackGameOver: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 28) {
                Text("GAME OVER")
                    .font(RTheme.mono(28, weight: .bold))
                    .foregroundStyle(RTheme.red)
                    .tracking(6)

                if game.score >= game.best && game.score > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(RTheme.bg)
                        Text("NEW HIGH SCORE!")
                            .font(RTheme.mono(11, weight: .bold))
                            .foregroundStyle(RTheme.bg)
                            .tracking(2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(RTheme.gold)
                    .clipShape(Capsule())
                }

                VStack(spacing: 16) {
                    gameScoreRow("SCORE", "\(game.score)", RTheme.gold)
                    gameScoreRow("HIGH SCORE", "\(game.best)", RTheme.green)
                    gameScoreRow("LEVEL", "\(game.level)", levelColor)
                }
                .padding(RTheme.pad)
                .background(RTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: RTheme.radius))
                .padding(.horizontal, RTheme.pad)

                VStack(spacing: 12) {
                    GoldButton(label: "PLAY AGAIN", action: {
                        withAnimation(.easeInOut(duration: 0.2)) { showGameOver = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            game.reset()
                            game.start()
                        }
                    })
                    Button("Back to Menu") { onDismiss() }
                        .font(RTheme.mono(14))
                        .foregroundStyle(RTheme.muted)
                }
                .padding(.horizontal, RTheme.pad)
            }
            Spacer()
        }
    }

    private func gameScoreRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label)
                .font(RTheme.mono(11))
                .foregroundStyle(RTheme.muted)
                .tracking(3)
            Spacer()
            Text(value)
                .font(RTheme.mono(28, weight: .bold))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Individual target view

struct WhackTargetView: View {
    let target: WhackTarget
    let onTap: () -> Void

    @State private var appeared = false
    @State private var tapped = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.9), target.color],
                        center: .center,
                        startRadius: 2,
                        endRadius: 30
                    )
                )
                .shadow(color: target.color.opacity(0.8), radius: 16)
                .frame(width: 58, height: 58)
                .scaleEffect(tapped ? 2.0 : (appeared ? 1.0 : 0.1))
                .opacity(tapped ? 0 : (appeared ? target.opacity : 0))

            // Timer ring
            if !tapped && appeared {
                Circle()
                    .trim(from: 0, to: target.opacity)
                    .stroke(target.color.opacity(0.5), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 66, height: 66)
            }
        }
        // Larger tap area
        .frame(width: 76, height: 76)
        .contentShape(Circle().size(CGSize(width: 76, height: 76)))
        .onTapGesture {
            guard !tapped else { return }
            withAnimation(.easeOut(duration: 0.18)) { tapped = true }
            onTap()
        }
        .onAppear {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) { appeared = true }
        }
    }
}

// MARK: - Floating score popup view

struct FloatingScoreView: View {
    let fp: FloatingScore
    @State private var offsetY: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        Text(fp.isCombo ? "+2 🔥" : "+1")
            .font(RTheme.mono(fp.isCombo ? 16 : 13, weight: .bold))
            .foregroundStyle(fp.isCombo ? RTheme.gold : RTheme.green)
            .offset(y: offsetY)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.85)) {
                    offsetY = -45
                    opacity = 0
                }
            }
    }
}

// MARK: - Floating score indicator

struct FloatingScore: Identifiable {
    let id = UUID()
    let x: CGFloat  // normalized
    let y: CGFloat
    let points: Int
    let isCombo: Bool
}

struct WhackTarget: Identifiable {
    let id = UUID()
    let x: CGFloat     // normalized 0-1
    let y: CGFloat
    let color: Color
    var opacity: CGFloat = 1.0  // countdown ring progress
}

// MARK: - Game engine

@MainActor
final class WhackGame: ObservableObject {
    @Published var score: Int = 0
    @Published var best: Int = 0
    @Published var lives: Int = 3
    @Published var level: Int = 1
    @Published var targets: [WhackTarget] = []
    @Published var isGameOver: Bool = false
    @Published var combo: Int = 0
    @Published var floatingPoints: [FloatingScore] = []

    private static let bestKey = "whackArcade_highScore"
    private let defaults = UserDefaults.standard
    private var spawnTask: Task<Void, Never>?
    private var decayTasks: [UUID: Task<Void, Never>] = [:]
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)

    /// How long a target lives (decreases with level)
    var targetLifetime: Double { max(0.7, 2.2 - Double(level - 1) * 0.2) }
    /// How often new targets spawn
    var spawnInterval: Double { max(0.55, 1.6 - Double(level - 1) * 0.15) }
    /// Max simultaneous targets
    var maxTargets: Int { min(4, 1 + (level / 2)) }

    private let targetColors: [Color] = [
        RTheme.gold, RTheme.green, RTheme.red,
        Color(red: 0.55, green: 0.35, blue: 0.95),
        Color(red: 0.30, green: 0.70, blue: 0.95)
    ]

    init() {
        best = defaults.integer(forKey: Self.bestKey)
    }

    func start() {
        guard !isGameOver else { return }
        spawnLoop()
    }

    func stop() {
        spawnTask?.cancel()
        decayTasks.values.forEach { $0.cancel() }
        decayTasks.removeAll()
    }

    private func spawnLoop() {
        spawnTask = Task {
            while !Task.isCancelled && !isGameOver {
                if targets.count < maxTargets {
                    spawnTarget()
                }
                try? await Task.sleep(nanoseconds: UInt64(spawnInterval * 1_000_000_000))
            }
        }
    }

    private func spawnTarget() {
        // Keep targets away from edges
        let x = CGFloat.random(in: 0.12...0.88)
        let y = CGFloat.random(in: 0.08...0.92)
        let color = targetColors.randomElement()!
        let target = WhackTarget(x: x, y: y, color: color)

        targets.append(target)
        startDecay(for: target)
    }

    private func startDecay(for target: WhackTarget) {
        let id = target.id
        let lifetime = targetLifetime
        let fps: Double = 20
        let step = 1.0 / (lifetime * fps)

        decayTasks[id] = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64((1.0 / fps) * 1_000_000_000))
                guard !Task.isCancelled else { return }

                if let idx = targets.firstIndex(where: { $0.id == id }) {
                    targets[idx].opacity -= step
                    if targets[idx].opacity <= 0 {
                        // Missed!
                        targets.removeAll { $0.id == id }
                        decayTasks.removeValue(forKey: id)
                        handleMiss()
                        return
                    }
                } else {
                    return // already tapped
                }
            }
        }
    }

    func tapTarget(id: UUID) {
        guard let idx = targets.firstIndex(where: { $0.id == id }) else { return }
        let tappedTarget = targets[idx]
        decayTasks[id]?.cancel()
        decayTasks.removeValue(forKey: id)

        // Brief delay to let tap animation show
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            self.targets.removeAll { $0.id == id }
        }

        impactLight.impactOccurred()
        combo += 1
        let points = combo >= 5 ? 2 : 1
        score += points
        level = (score / 8) + 1

        // Floating score indicator
        let fp = FloatingScore(x: tappedTarget.x, y: tappedTarget.y, points: points, isCombo: combo >= 5)
        floatingPoints.append(fp)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            self.floatingPoints.removeAll { $0.id == fp.id }
        }

        if score > best {
            best = score
            defaults.set(best, forKey: Self.bestKey)
        }
    }

    private func handleMiss() {
        impactHeavy.impactOccurred()
        combo = 0  // reset combo on miss
        lives -= 1
        if lives <= 0 {
            stop()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isGameOver = true
            }
        }
    }

    func reset() {
        stop()
        score = 0
        lives = 3
        level = 1
        combo = 0
        targets = []
        floatingPoints = []
        isGameOver = false
        decayTasks.removeAll()
    }
}
