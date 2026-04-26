import SwiftUI
import AudioToolbox

// MARK: - Grid Arcade Game
// A fixed 4x4 grid of circles. One lights up at random - tap it before it fades.
// Multiple can light up at higher levels. Miss = lose a life.

struct GridCell: Identifiable {
    let id = UUID()
    let row: Int
    let col: Int
    var isActive = false
    var flashOpacity: Double = 0
}

@MainActor
class GridGame: ObservableObject {
    @Published var cells: [GridCell] = []
    @Published var lives = 3
    @Published var score = 0
    @Published var level = 1
    @Published var phase: GridPhase = .idle
    @Published var highScore = 0
    @Published var combo = 0

    private let defaults = UserDefaults.standard
    private static let bestKey = "gridArcade_highScore"
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private var spawnTask: Task<Void, Never>?
    private var decayTasks: [UUID: Task<Void, Never>] = [:]

    enum GridPhase { case idle, playing, dead }

    var cellLifetime: Double { max(0.4, 1.4 - Double(level - 1) * 0.06) }
    var spawnInterval: Double { max(0.3, 0.95 - Double(level - 1) * 0.04) }
    var maxActive: Int { min(3, 1 + (level / 4)) }

    init() {
        highScore = defaults.integer(forKey: Self.bestKey)
        resetGrid()
    }

    func start() {
        highScore = defaults.integer(forKey: Self.bestKey)
        score = 0
        lives = 3
        level = 1
        combo = 0
        phase = .playing
        resetGrid()
        spawnLoop()
    }

    private func resetGrid() {
        cells = []
        for row in 0..<4 {
            for col in 0..<4 {
                cells.append(GridCell(row: row, col: col))
            }
        }
    }

    private func spawnLoop() {
        spawnTask = Task {
            while !Task.isCancelled && phase == .playing {
                let interval = spawnInterval
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled && phase == .playing else { break }

                let activeCount = cells.filter { $0.isActive }.count
                if activeCount < maxActive {
                    spawnRandomCell()
                }
            }
        }
    }

    private func spawnRandomCell() {
        let inactiveIndices = cells.indices.filter { !cells[$0].isActive }
        guard let idx = inactiveIndices.randomElement() else { return }
        let id = cells[idx].id
        cells[idx].isActive = true
        withAnimation(.easeIn(duration: 0.1)) {
            cells[idx].flashOpacity = 1.0
        }

        let lifetime = cellLifetime
        decayTasks[id] = Task {
            try? await Task.sleep(for: .seconds(lifetime))
            guard !Task.isCancelled else { return }
            // Cell expired without tap
            if let i = cells.firstIndex(where: { $0.id == id }), cells[i].isActive {
                withAnimation(.easeOut(duration: 0.15)) {
                    cells[i].isActive = false
                    cells[i].flashOpacity = 0
                }
                handleMiss()
            }
        }
    }

    func tap(cell: GridCell) {
        guard phase == .playing else { return }
        guard cell.isActive else {
            // Tapped inactive cell
            if defaults.bool(forKey: "hapticsEnabled") { impactHeavy.impactOccurred() }
            return
        }

        decayTasks[cell.id]?.cancel()
        decayTasks.removeValue(forKey: cell.id)

        if let i = cells.firstIndex(where: { $0.id == cell.id }) {
            withAnimation(.easeOut(duration: 0.1)) {
                cells[i].isActive = false
                cells[i].flashOpacity = 0
            }
        }

        if defaults.bool(forKey: "hapticsEnabled") { impactLight.impactOccurred() }
        if UserDefaults.standard.object(forKey: "soundEnabled") == nil || UserDefaults.standard.bool(forKey: "soundEnabled") { AudioServicesPlaySystemSound(1104) }
        combo += 1
        score += combo >= 5 ? 2 : 1
        level = (score / 6) + 1

        if score > highScore {
            highScore = score
            defaults.set(highScore, forKey: Self.bestKey)
        }
    }

    private func handleMiss() {
        if defaults.bool(forKey: "hapticsEnabled") { impactHeavy.impactOccurred() }
        if UserDefaults.standard.object(forKey: "soundEnabled") == nil || UserDefaults.standard.bool(forKey: "soundEnabled") { AudioServicesPlaySystemSound(1107) }
        combo = 0
        lives -= 1
        if lives <= 0 { endGame() }
    }

    func endGame() {
        spawnTask?.cancel()
        for task in decayTasks.values { task.cancel() }
        decayTasks = [:]
        phase = .dead
    }
}

// MARK: - Main View

struct GridArcadeView: View {
    let onDismiss: () -> Void

    @StateObject private var game = GridGame()
    @State private var shakeOffset: CGFloat = 0
    @State private var prevLives = 3

    private let cols = 4
    private let rows = 4

    var body: some View {
        ZStack {
            RTheme.bg.ignoresSafeArea()

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
                        Text("GRID")
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

                // Level + combo
                if game.phase == .playing {
                    HStack(spacing: 16) {
                        Text("LVL \(game.level)")
                            .font(RTheme.mono(9, weight: .bold))
                            .foregroundStyle(RTheme.muted)
                            .tracking(3)
                        Spacer()
                        if game.combo >= 3 {
                            HStack(spacing: 4) {
                                Text("x\(game.combo)")
                                    .font(RTheme.mono(12, weight: .black))
                                    .foregroundStyle(RTheme.gold)
                                Text("COMBO")
                                    .font(RTheme.mono(9, weight: .bold))
                                    .foregroundStyle(RTheme.gold.opacity(0.7))
                                    .tracking(2)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, RTheme.pad)
                    .padding(.bottom, 4)
                    .animation(.spring(response: 0.3), value: game.combo)
                }

                Spacer()

                // Game content
                ZStack {
                    if game.phase == .idle {
                        idleScreen
                    } else if game.phase == .dead {
                        deathScreen
                    } else {
                        gridField
                    }
                }
                .offset(x: shakeOffset)
                .onChange(of: game.lives) { _, newVal in
                    if newVal < prevLives { shakeScreen() }
                    prevLives = newVal
                }

                Spacer()
            }
        }
        .onAppear { game.start() }
    }

    // MARK: - Grid

    private var gridField: some View {
        GeometryReader { geo in
            let cellSize = min(geo.size.width, geo.size.height) / CGFloat(cols) - 12
            let gridWidth = cellSize * CGFloat(cols) + 12 * CGFloat(cols - 1)
            let hPad = (geo.size.width - gridWidth) / 2
            let gridHeight = cellSize * CGFloat(rows) + 12 * CGFloat(rows - 1)
            let vPad = (geo.size.height - gridHeight) / 2

            ZStack {
                ForEach(game.cells) { cell in
                    GridCellView(cell: cell, size: cellSize)
                        .position(
                            x: hPad + (cellSize / 2) + CGFloat(cell.col) * (cellSize + 12),
                            y: vPad + (cellSize / 2) + CGFloat(cell.row) * (cellSize + 12)
                        )
                        .onTapGesture { game.tap(cell: cell) }
                }
            }
        }
        .padding(24)
    }

    private var idleScreen: some View {
        VStack(spacing: 24) {
            Text("🟦").font(.system(size: 64))
            Text("GRID")
                .font(RTheme.serif(36, weight: .black))
                .foregroundStyle(RTheme.gold)
                .tracking(6)
            Text("Tap the lit cell before it fades")
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

// MARK: - Grid Cell View

struct GridCellView: View {
    let cell: GridCell
    let size: CGFloat

    @State private var hitFlash = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(cell.isActive
                    ? RTheme.gold.opacity(0.9)
                    : RTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.22)
                        .stroke(cell.isActive ? RTheme.gold : RTheme.faint.opacity(0.4), lineWidth: 1.5)
                )
                .shadow(color: cell.isActive ? RTheme.gold.opacity(0.6) : .clear, radius: 10)
                .scaleEffect(cell.isActive ? 1.05 : 1.0)
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: cell.isActive)
    }
}
