import SwiftUI
import UIKit
import AudioToolbox

// MARK: - Memory Arcade
// A grid lights up briefly. Memorize which cells. Then tap them all from memory.
// More cells + less display time as score grows. 3 lives.

struct MemoryArcadeView: View {
    let onDismiss: () -> Void

    @StateObject private var game = MemoryGame()
    @State private var showGameOver = false
    @State private var shakeOffset: CGFloat = 0
    @State private var prevLives: Int = 3

    var body: some View {
        ZStack {
            RTheme.bg.ignoresSafeArea()

            if showGameOver {
                memoryGameOver
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                VStack(spacing: 0) {
                    memoryTopBar
                    memoryStatsRow
                    memoryPhaseLabel
                    memoryGrid
                        .layoutPriority(1)
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
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showGameOver = true
                }
            }
        }
        .onAppear { game.startRound() }
        .onDisappear { game.stop() }
    }

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

    // MARK: - Top bar

    private var memoryTopBar: some View {
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
            Text("MEMORY")
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

    private var memoryStatsRow: some View {
        HStack(spacing: 0) {
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
                Text("ROUNDS")
                    .font(RTheme.mono(9))
                    .foregroundStyle(RTheme.faint)
                    .tracking(3)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 2) {
                Text("\(game.targetCount)")
                    .font(RTheme.mono(22, weight: .bold))
                    .foregroundStyle(levelColor)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: game.targetCount)
                Text("CELLS")
                    .font(RTheme.mono(9))
                    .foregroundStyle(RTheme.faint)
                    .tracking(2)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, RTheme.pad)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var levelColor: Color {
        switch game.targetCount {
        case ...4: return RTheme.gold
        case 5...6: return RTheme.green
        default: return RTheme.red
        }
    }

    // MARK: - Phase label

    private var memoryPhaseLabel: some View {
        VStack(spacing: 4) {
            Text(game.phaseLabel)
                .font(RTheme.mono(18, weight: .bold))
                .foregroundStyle(game.phase == .recall ? RTheme.white : RTheme.gold)
                .tracking(4)
                .animation(.easeInOut(duration: 0.2), value: game.phaseLabel)

            if game.phase == .memorize {
                // Display countdown bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(RTheme.faint.opacity(0.3))
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(RTheme.gold)
                            .frame(width: geo.size.width * game.memorizeProgress, height: 3)
                            .animation(.linear(duration: 0.1), value: game.memorizeProgress)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, RTheme.pad)
            } else if game.phase == .recall {
                Text("\(game.tapsLeft) left")
                    .font(RTheme.mono(11))
                    .foregroundStyle(RTheme.muted)
                    .tracking(2)
            } else {
                Color.clear.frame(height: 14)
            }
        }
        .frame(height: 60)
        .padding(.horizontal, RTheme.pad)
        .padding(.bottom, 8)
    }

    // MARK: - Grid

    private var memoryGrid: some View {
        GeometryReader { geo in
            let cols = game.gridCols
            let rows = game.gridRows
            let spacing: CGFloat = 10
            let availW = geo.size.width - CGFloat(cols - 1) * spacing
            let availH = geo.size.height - CGFloat(rows - 1) * spacing - 16
            let cellSize = min(availW / CGFloat(cols), availH / CGFloat(rows))

            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<cols, id: \.self) { col in
                            let idx = row * cols + col
                            MemoryCellView(
                                state: game.cellState(at: idx),
                                size: cellSize,
                                onTap: {
                                    game.tapCell(at: idx)
                                }
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .padding(.horizontal, RTheme.pad)
        .padding(.bottom, 40)
    }

    // MARK: - Game Over

    private var memoryGameOver: some View {
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
                    gameScoreRow("ROUNDS", "\(game.score)", RTheme.gold)
                    gameScoreRow("BEST", "\(game.best)", RTheme.green)
                    gameScoreRow("MAX CELLS", "\(game.targetCount)", levelColor)
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
                            game.startRound()
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

// MARK: - Cell view

enum MemoryCellState {
    case dark       // default, off
    case lit        // shown during memorize phase
    case correct    // tapped correctly during recall
    case wrong      // tapped incorrectly
    case missed     // was a target but not tapped
}

struct MemoryCellView: View {
    let state: MemoryCellState
    let size: CGFloat
    let onTap: () -> Void

    @State private var appeared = false
    @State private var tapped = false

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(cellColor)
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(borderColor, lineWidth: state == .dark ? 1 : 0)
            )
            .shadow(color: glowColor, radius: state == .lit ? 12 : 0)
            .scaleEffect(scaleEffect)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: state)
            .onTapGesture {
                onTap()
            }
    }

    private var cellColor: Color {
        switch state {
        case .dark:    return RTheme.surface
        case .lit:     return RTheme.gold
        case .correct: return RTheme.green
        case .wrong:   return RTheme.red
        case .missed:  return RTheme.gold.opacity(0.4)
        }
    }

    private var borderColor: Color {
        state == .dark ? RTheme.faint : .clear
    }

    private var glowColor: Color {
        switch state {
        case .lit:     return RTheme.gold.opacity(0.6)
        case .correct: return RTheme.green.opacity(0.5)
        case .wrong:   return RTheme.red.opacity(0.5)
        default:       return .clear
        }
    }

    private var scaleEffect: CGFloat {
        switch state {
        case .lit:     return 1.06
        case .correct: return 0.94
        case .wrong:   return 0.88
        default:       return 1.0
        }
    }
}

// MARK: - Game engine

enum MemoryPhase {
    case idle
    case memorize
    case recall
    case feedback  // brief flash before next round
}

@MainActor
final class MemoryGame: ObservableObject {
    @Published var score: Int = 0
    @Published var best: Int = 0
    @Published var lives: Int = 3
    @Published var isGameOver: Bool = false
    @Published var phase: MemoryPhase = .idle
    @Published var cellStates: [MemoryCellState] = Array(repeating: .dark, count: 16)
    @Published var memorizeProgress: CGFloat = 1.0

    // Which cells are the targets this round
    private var targetIndices: Set<Int> = []
    // Which targets the user has tapped correctly this round
    private var correctTaps: Set<Int> = []

    private var roundTask: Task<Void, Never>?
    private static let bestKey = "memoryArcade_highScore"
    private let defaults = UserDefaults.standard
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)

    // Grid is always 4x4
    let gridCols = 4
    let gridRows = 4
    private let totalCells = 16

    // Difficulty scaling
    var targetCount: Int { min(3 + score, 10) }
    var displayDuration: Double { max(1.0, 2.5 - Double(score) * 0.08) }

    var tapsLeft: Int { targetIndices.count - correctTaps.count }

    var phaseLabel: String {
        switch phase {
        case .idle:     return ""
        case .memorize: return "MEMORIZE"
        case .recall:   return "RECALL!"
        case .feedback: return ""
        }
    }

    init() {
        best = defaults.integer(forKey: Self.bestKey)
        cellStates = Array(repeating: .dark, count: 16)
    }

    func startRound() {
        guard !isGameOver else { return }
        phase = .idle
        correctTaps = []
        cellStates = Array(repeating: .dark, count: totalCells)

        // Pick random target cells
        let n = targetCount
        let indices = Array(0..<totalCells).shuffled()
        targetIndices = Set(indices.prefix(n))

        roundTask = Task {
            // Brief pause before showing
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }

            // Show the cells
            phase = .memorize
            for i in targetIndices {
                cellStates[i] = .lit
            }

            // Countdown animation
            let fps = 20.0
            let steps = Int(displayDuration * fps)
            for step in 0...steps {
                guard !Task.isCancelled else { return }
                let progress = 1.0 - Double(step) / Double(steps)
                memorizeProgress = progress
                try? await Task.sleep(nanoseconds: UInt64((1.0 / fps) * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }

            // Hide cells and enter recall phase
            cellStates = Array(repeating: .dark, count: totalCells)
            memorizeProgress = 1.0
            phase = .recall
        }
    }

    func tapCell(at index: Int) {
        guard phase == .recall else { return }
        guard cellStates[index] == .dark else { return }  // already tapped

        if targetIndices.contains(index) {
            // Correct!
            if defaults.bool(forKey: "hapticsEnabled") { impactLight.impactOccurred() }
            if defaults.object(forKey: "soundEnabled") == nil || defaults.bool(forKey: "soundEnabled") {
                AudioServicesPlaySystemSound(1104)
            }
            cellStates[index] = .correct
            correctTaps.insert(index)

            if correctTaps.count == targetIndices.count {
                // Round complete!
                roundComplete()
            }
        } else {
            // Wrong tap
            if defaults.bool(forKey: "hapticsEnabled") { impactHeavy.impactOccurred() }
            if defaults.object(forKey: "soundEnabled") == nil || defaults.bool(forKey: "soundEnabled") {
                AudioServicesPlaySystemSound(1107)
            }
            cellStates[index] = .wrong
            loseLife()
        }
    }

    private func roundComplete() {
        roundTask?.cancel()
        score += 1
        if score > best {
            best = score
            defaults.set(best, forKey: Self.bestKey)
        }
        phase = .feedback

        // Flash all correct green, then start next round
        for i in targetIndices {
            cellStates[i] = .correct
        }

        roundTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            startRound()
        }
    }

    private func loseLife() {
        lives -= 1

        // Reveal all missed targets
        for i in targetIndices where !correctTaps.contains(i) {
            cellStates[i] = .missed
        }

        if lives <= 0 {
            roundTask?.cancel()
            phase = .feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.isGameOver = true
            }
        } else {
            // Brief pause showing what was missed, then next round
            roundTask?.cancel()
            phase = .feedback
            roundTask = Task {
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard !Task.isCancelled else { return }
                startRound()
            }
        }
    }

    func stop() {
        roundTask?.cancel()
    }

    func reset() {
        stop()
        score = 0
        lives = 3
        isGameOver = false
        phase = .idle
        cellStates = Array(repeating: .dark, count: totalCells)
        targetIndices = []
        correctTaps = []
        memorizeProgress = 1.0
    }

    func cellState(at index: Int) -> MemoryCellState {
        guard index < cellStates.count else { return .dark }
        return cellStates[index]
    }
}
