import SwiftUI
import UIKit
import AudioToolbox

// MARK: - Drop Arcade Game
// 5 balls sit at top. One drops randomly. Tap it before it lands.
// Speed increases every 5 catches. 3 lives. Instant reset loop.

struct DropArcadeView: View {
    let onDismiss: () -> Void

    @StateObject private var game = DropArcadeGame()
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
                    topBar
                    statsRow
                    Spacer()
                    ballField
                    Spacer(minLength: 60)
                }
                .offset(x: shakeOffset)
            }
        }
        .onChange(of: game.lives) { _, newLives in
            if newLives < prevLives {
                shakeScreen()
            }
            prevLives = newLives
        }
        .onChange(of: game.isGameOver) { _, over in
            if over {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showGameOver = true
                }
            }
        }
        .onAppear { game.startRound() }
    }

    // MARK: - Top bar

    private func shakeScreen() {
        let shakes: [CGFloat] = [-10, 10, -8, 8, -4, 4, 0]
        var delay = 0.0
        for val in shakes {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 0.05)) { shakeOffset = val }
            }
            delay += 0.055
        }
    }

    private var topBar: some View {
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
            Text("DROP")
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

    private var statsRow: some View {
        HStack(spacing: 0) {
            // Lives
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < game.lives ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundStyle(i < game.lives ? RTheme.red : RTheme.faint)
                        .scaleEffect(i < game.lives ? 1.0 : 0.8)
                        .animation(.spring(response: 0.2), value: game.lives)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Score + combo
            VStack(spacing: 2) {
                Text("\(game.score)")
                    .font(RTheme.mono(40, weight: .bold))
                    .foregroundStyle(RTheme.accent)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: game.score)
                if game.combo >= 3 {
                    Text("x\(game.combo) COMBO")
                        .font(RTheme.mono(9, weight: .bold))
                        .foregroundStyle(RTheme.green)
                        .tracking(2)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("SCORE")
                        .font(RTheme.mono(9))
                        .foregroundStyle(RTheme.faint)
                        .tracking(3)
                }
            }
            .animation(.spring(response: 0.2), value: game.combo)
            .frame(maxWidth: .infinity)

            // Level + best
            VStack(spacing: 2) {
                Text("LV \(game.level)")
                    .font(RTheme.mono(22, weight: .bold))
                    .foregroundStyle(levelColor)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: game.level)
                Text("BEST \(game.best)")
                    .font(RTheme.mono(9))
                    .foregroundStyle(game.isNewBest ? RTheme.accent : RTheme.faint)
                    .tracking(2)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, RTheme.pad)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var levelColor: Color {
        switch game.level {
        case 1: return RTheme.accent
        case 2: return RTheme.green
        case 3...: return RTheme.red
        default: return RTheme.accent
        }
    }

    // MARK: - Ball field

    private var ballField: some View {
        GeometryReader { geo in
            ZStack {
                // Floor indicator
                Rectangle()
                    .fill(RTheme.faint.opacity(0.4))
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.92)

                // DANGER zone highlight when ball is close
                if game.dropProgress > 0.7 && game.fallingIndex >= 0 {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, RTheme.red.opacity(0.08)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .ignoresSafeArea()
                }

                // Balls
                let spacing = geo.size.width / CGFloat(5 + 1)
                ForEach(0..<5, id: \.self) { i in
                    ballView(index: i, spacing: spacing, geoSize: geo.size)
                }

                // Hit burst particles
                ForEach(game.bursts) { burst in
                    BurstView(burst: burst)
                        .position(x: burst.x, y: burst.y)
                }
            }
        }
        .frame(height: 500)
        .padding(.horizontal, 0)
    }

    @ViewBuilder
    private func ballView(index: Int, spacing: CGFloat, geoSize: CGSize) -> some View {
        let isFalling = index == game.fallingIndex
        let isHit     = game.hitIndex == index
        let isMissed  = game.missedIndex == index
        let topY      = geoSize.height * 0.06
        let fallY     = topY + game.dropProgress * geoSize.height * 0.86
        let xPos      = spacing * CGFloat(index + 1)

        if isHit {
            // Explode out on hit
            Circle()
                .fill(RTheme.accent)
                .shadow(color: RTheme.accent, radius: 30)
                .frame(width: 52, height: 52)
                .scaleEffect(game.hitScale)
                .opacity(game.hitOpacity)
                .position(x: xPos, y: fallY)
        } else if isMissed {
            // Flash red and shrink on miss
            Circle()
                .fill(RTheme.red)
                .shadow(color: RTheme.red, radius: 20)
                .frame(width: 52, height: 52)
                .scaleEffect(game.missScale)
                .opacity(game.missOpacity)
                .position(x: xPos, y: geoSize.height * 0.92)
        } else if isFalling {
            // The live falling ball
            ZStack {
                // Trail
                ForEach(0..<4, id: \.self) { t in
                    Circle()
                        .fill(RTheme.accent.opacity(0.12 - Double(t) * 0.02))
                        .frame(width: 44 - CGFloat(t) * 4, height: 44 - CGFloat(t) * 4)
                        .offset(y: -CGFloat(t + 1) * 14 * game.dropProgress)
                }
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.9), RTheme.accent],
                            center: .center,
                            startRadius: 2,
                            endRadius: 22
                        )
                    )
                    .shadow(color: RTheme.accent.opacity(0.9), radius: 18)
                    .frame(width: 44, height: 44)
            }
            .position(x: xPos, y: fallY)
            .onTapGesture { game.tapBall(index: index) }
            .animation(.linear(duration: game.fallDuration), value: game.dropProgress)
        } else {
            // Static ghost ball at top
            Circle()
                .fill(RTheme.surface)
                .overlay(
                    Circle()
                        .stroke(
                            game.fallingIndex < 0 ? RTheme.accent.opacity(0.5) : RTheme.faint,
                            lineWidth: 2
                        )
                )
                .frame(width: 44, height: 44)
                .position(x: xPos, y: topY)
        }
    }

    // MARK: - Game Over

    private var gameOverOverlay: some View {
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
                            .foregroundStyle(.white)
                        Text("NEW HIGH SCORE!")
                            .font(RTheme.mono(11, weight: .bold))
                            .foregroundStyle(.white)
                            .tracking(2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(RTheme.accent)
                    .clipShape(Capsule())
                }

                VStack(spacing: 16) {
                    scoreRow(label: "SCORE", value: "\(game.score)", color: RTheme.accent)
                    scoreRow(label: "HIGH SCORE", value: "\(game.best)", color: RTheme.green)
                    scoreRow(label: "LEVEL", value: "\(game.level)", color: levelColor)
                }
                .padding(RTheme.pad)
                .background(RTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: RTheme.radius))
                .padding(.horizontal, RTheme.pad)

                VStack(spacing: 12) {
                    PrimaryButton(label: "Play Again", action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showGameOver = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            game.reset()
                            game.startRound()
                        }
                    })
                    Button("Back to Menu") {
                        onDismiss()
                    }
                    .font(RTheme.mono(14))
                    .foregroundStyle(RTheme.muted)
                }
                .padding(.horizontal, RTheme.pad)
            }

            Spacer()
        }
    }

    private func scoreRow(label: String, value: String, color: Color) -> some View {
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

// MARK: - Burst particle

struct Burst: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
}

struct BurstView: View {
    let burst: Burst
    @State private var scale: CGFloat = 0.2
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Circle()
                    .fill(RTheme.accent.opacity(0.8))
                    .frame(width: 6, height: 6)
                    .offset(x: cos(Double(i) / 8 * .pi * 2) * 28 * scale,
                            y: sin(Double(i) / 8 * .pi * 2) * 28 * scale)
            }
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) {
                scale = 1.0
                opacity = 0
            }
        }
    }
}

// MARK: - Game engine

@MainActor
final class DropArcadeGame: ObservableObject {
    @Published var score: Int = 0
    @Published var best: Int = 0
    @Published var lives: Int = 3
    @Published var level: Int = 1
    @Published var combo: Int = 0
    @Published var isNewBest: Bool = false
    @Published var fallingIndex: Int = -1
    @Published var dropProgress: CGFloat = 0
    @Published var isGameOver: Bool = false
    @Published var bursts: [Burst] = []

    // Hit / miss feedback
    @Published var hitIndex: Int = -1
    @Published var hitScale: CGFloat = 1.0
    @Published var hitOpacity: Double = 1.0
    @Published var missedIndex: Int = -1
    @Published var missScale: CGFloat = 1.0
    @Published var missOpacity: Double = 1.0

    var fallDuration: Double { max(0.45, 2.0 - Double(level - 1) * 0.18) }

    private static let bestKey = "dropArcade_highScore"
    private let defaults = UserDefaults.standard
    private var fallTask: Task<Void, Never>?
    private var impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private var impactLight = UIImpactFeedbackGenerator(style: .light)
    private var notif       = UINotificationFeedbackGenerator()

    init() {
        best = defaults.integer(forKey: Self.bestKey)
    }

    func startRound() {
        guard !isGameOver else { return }
        fallTask?.cancel()
        hitIndex = -1
        hitScale = 1.0
        hitOpacity = 1.0
        missedIndex = -1
        missScale = 1.0
        missOpacity = 1.0
        dropProgress = 0
        fallingIndex = -1

        // Brief pause before next drop - shorter when in combo
        let pause: Double = score == 0 ? 0.6 : (combo >= 3 ? 0.2 : 0.3)

        fallTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
            guard !Task.isCancelled else { return }

            let idx = Int.random(in: 0..<5)
            fallingIndex = idx

            // Animate the fall
            withAnimation(.linear(duration: fallDuration)) {
                dropProgress = 1.0
            }

            // Miss detection: fire after fall duration
            try? await Task.sleep(nanoseconds: UInt64(fallDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }

            if fallingIndex == idx {
                // Ball was not tapped - miss
                handleMiss(index: idx)
            }
        }
    }

    func tapBall(index: Int) {
        guard fallingIndex == index, !isGameOver else { return }
        fallTask?.cancel()

        if defaults.bool(forKey: "hapticsEnabled") { impactLight.impactOccurred() }
        if UserDefaults.standard.object(forKey: "soundEnabled") == nil || UserDefaults.standard.bool(forKey: "soundEnabled") { AudioServicesPlaySystemSound(1104) } // click tap sound

        let tappedIdx = index
        fallingIndex = -1
        combo += 1
        // Bonus point for combo streaks
        let bonus = combo >= 5 ? 2 : 1
        score += bonus
        level = (score / 5) + 1

        if score > best {
            best = score
            isNewBest = true
            defaults.set(best, forKey: Self.bestKey)
        }

        // Hit animation
        hitIndex = tappedIdx
        withAnimation(.easeOut(duration: 0.18)) {
            hitScale = 2.2
            hitOpacity = 0
        }

        // Burst particles (approximate position - resets anyway)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.bursts.append(Burst(x: 0, y: 0))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.bursts.removeAll()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            self.startRound()
        }
    }

    private func handleMiss(index: Int) {
        if defaults.bool(forKey: "hapticsEnabled") { impactHeavy.impactOccurred() }
        if UserDefaults.standard.object(forKey: "soundEnabled") == nil || UserDefaults.standard.bool(forKey: "soundEnabled") { AudioServicesPlaySystemSound(1107) } // error sound

        fallingIndex = -1
        combo = 0
        lives -= 1
        missedIndex = index

        withAnimation(.easeOut(duration: 0.25)) {
            missScale = 0.2
            missOpacity = 0
        }

        if lives <= 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.isGameOver = true
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                self.startRound()
            }
        }
    }

    func reset() {
        fallTask?.cancel()
        score = 0
        lives = 3
        level = 1
        combo = 0
        isNewBest = false
        fallingIndex = -1
        dropProgress = 0
        isGameOver = false
        hitIndex = -1
        hitScale = 1.0
        hitOpacity = 1.0
        missedIndex = -1
        missScale = 1.0
        missOpacity = 1.0
        bursts = []
    }
}
