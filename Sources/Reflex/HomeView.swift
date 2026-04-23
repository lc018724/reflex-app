import SwiftUI

struct HomeView: View {
    let onSelect: (TestMode) -> Void

    private let store = TestStore()
    @State private var overallBest: Double? = nil
    @State private var completedCount: Int = 0

    // Group modes by tier
    private let tiers: [(String, [TestMode])] = [
        ("SPEED",     [.flash, .fallingBall, .antiTap, .doubleFlash]),
        ("ATTENTION", [.find, .colorTap, .oddOneOut, .peripheral]),
        ("COGNITION", [.stroop, .reverseStroop, .mirror, .goNoGo]),
        ("MEMORY",    [.math, .sequence, .nBack, .digitMatch]),
        ("EXPERT",    [.simon, .speedSort, .rhythm, .dualTrack]),
    ]

    private let arcadeModes: [TestMode] = [.dropArcade]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // Hero
                heroSection

                // Tier groups
                ForEach(tiers, id: \.0) { tierName, modes in
                    tierSection(title: tierName, modes: modes)
                }

                // Arcade section
                arcadeSection

                benchmarkFooter
                    .padding(.top, 20)
                    .padding(.bottom, 60)
            }
        }
        .onAppear { loadStats() }
    }

    private func loadStats() {
        let bests = TestMode.allCases.compactMap { store.bestMS(for: $0) }
        overallBest = bests.min()
        completedCount = bests.count
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 0) {
            // Title lockup
            VStack(spacing: 6) {
                Text("REFLEX")
                    .font(RTheme.serif(56, weight: .black))
                    .foregroundStyle(RTheme.gold)
                    .tracking(14)

                Text("REACTION TRAINING")
                    .font(RTheme.mono(10, weight: .medium))
                    .foregroundStyle(RTheme.muted)
                    .tracking(5)
            }
            .padding(.top, 56)

            // Stats row
            HStack(spacing: 0) {
                heroStat(label: "TESTS", value: "21")
                Divider().overlay(RTheme.faint).frame(height: 28)
                heroStat(label: "DONE", value: "\(completedCount)")
                Divider().overlay(RTheme.faint).frame(height: 28)
                heroStat(label: "STREAK", value: "\(store.streak)🔥")
            }
            .padding(.horizontal, RTheme.pad)
            .padding(.top, 20)

            if let ms = overallBest {
                bestBadge(ms: ms)
                    .padding(.top, 16)
                    .padding(.horizontal, RTheme.pad)
            } else {
                Text("Complete a test to establish your baseline")
                    .font(RTheme.mono(11))
                    .foregroundStyle(RTheme.faint)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                    .padding(.horizontal, RTheme.pad)
            }
        }
        .padding(.bottom, 32)
    }

    private func heroStat(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(RTheme.mono(22, weight: .bold))
                .foregroundStyle(RTheme.white)
            Text(label)
                .font(RTheme.mono(9))
                .foregroundStyle(RTheme.faint)
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
    }

    private func bestBadge(ms: Double) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PERSONAL BEST")
                    .font(RTheme.mono(9, weight: .medium))
                    .foregroundStyle(RTheme.muted)
                    .tracking(2)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.0f", ms))
                        .font(RTheme.mono(36, weight: .bold))
                        .foregroundStyle(speedColor(ms))
                    Text("ms")
                        .font(RTheme.mono(14))
                        .foregroundStyle(RTheme.muted)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(ReactionBenchmarks.label(ms: ms).uppercased())
                    .font(RTheme.mono(10, weight: .bold))
                    .foregroundStyle(speedColor(ms))
                    .tracking(2)
                Text("TOP \(100 - ReactionBenchmarks.percentile(ms: ms))%")
                    .font(RTheme.mono(10))
                    .foregroundStyle(RTheme.muted)
            }
        }
        .padding(RTheme.padSm)
        .background(RTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
    }

    // MARK: - Tier section

    private func tierSection(title: String, modes: [TestMode]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(RTheme.mono(10, weight: .bold))
                    .foregroundStyle(RTheme.muted)
                    .tracking(4)
                Rectangle()
                    .fill(RTheme.faint)
                    .frame(height: 1)
            }
            .padding(.horizontal, RTheme.pad)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(modes) { mode in
                    ModeCard(mode: mode, best: store.bestMS(for: mode)) {
                        onSelect(mode)
                    }
                }
            }
            .padding(.horizontal, RTheme.pad)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Footer

    private var benchmarkFooter: some View {
        VStack(spacing: 12) {
            Text("BENCHMARKS")
                .font(RTheme.mono(9, weight: .bold))
                .foregroundStyle(RTheme.faint)
                .tracking(4)

            HStack(spacing: 8) {
                benchmarkBubble("F1 driver", "150ms", RTheme.green)
                benchmarkBubble("Elite athlete", "175ms", RTheme.gold)
                benchmarkBubble("Average", "235ms", RTheme.muted)
                benchmarkBubble("Impaired", "300ms+", RTheme.red)
            }
            .padding(.horizontal, RTheme.pad)

            Text("Times are simple reaction. Cognitive tests will be higher.")
                .font(RTheme.mono(9))
                .foregroundStyle(RTheme.faint.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, RTheme.pad)
        }
    }

    private func benchmarkBubble(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(RTheme.mono(11, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(RTheme.mono(8))
                .foregroundStyle(RTheme.faint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Arcade section

    private var arcadeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ARCADE")
                    .font(RTheme.mono(10, weight: .bold))
                    .foregroundStyle(RTheme.gold.opacity(0.8))
                    .tracking(4)
                Rectangle()
                    .fill(RTheme.gold.opacity(0.25))
                    .frame(height: 1)
            }
            .padding(.horizontal, RTheme.pad)

            ForEach(arcadeModes) { mode in
                ArcadeCard(mode: mode) { onSelect(mode) }
                    .padding(.horizontal, RTheme.pad)
            }
        }
        .padding(.bottom, 20)
    }

    private func speedColor(_ ms: Double) -> Color {
        switch ms {
        case ..<200: return RTheme.green
        case 200..<270: return RTheme.gold
        default: return RTheme.red
        }
    }
}

// MARK: - Mode Card

struct ModeCard: View {
    let mode: TestMode
    let best: Double?
    let onTap: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(mode.emoji)
                        .font(.system(size: 22))
                    Spacer()
                    if let ms = best {
                        Text(String(format: "%.0f", ms))
                            .font(RTheme.mono(13, weight: .bold))
                            .foregroundStyle(msColor(ms))
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(RTheme.faint)
                    }
                }

                Text(mode.title)
                    .font(RTheme.rounded(15, weight: .bold))
                    .foregroundStyle(RTheme.white)
                    .tracking(1)

                Text(mode.subtitle)
                    .font(RTheme.mono(10))
                    .foregroundStyle(RTheme.muted)
                    .lineLimit(1)
            }
            .padding(RTheme.padSm)
            .background(RTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
            .scaleEffect(pressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeIn(duration: 0.07)) { pressed = true } }
                .onEnded   { _ in withAnimation(.easeOut(duration: 0.15)) { pressed = false } }
        )
    }

    private func msColor(_ ms: Double) -> Color {
        switch ms {
        case ..<200: return RTheme.green
        case 200..<270: return RTheme.gold
        default: return RTheme.red
        }
    }
}

// MARK: - Arcade Card

struct ArcadeCard: View {
    let mode: TestMode
    let onTap: () -> Void

    @State private var pressed = false
    @State private var animBall: CGFloat = 0

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Animated mini ball preview
                ZStack {
                    RTheme.bg
                        .frame(width: 64, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))

                    // Ghost balls row + one animated drop
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { i in
                            Circle()
                                .fill(i == 2 ? RTheme.gold : RTheme.surface)
                                .overlay(Circle().stroke(i == 2 ? Color.clear : RTheme.faint, lineWidth: 1))
                                .frame(width: 9, height: 9)
                                .shadow(color: i == 2 ? RTheme.gold.opacity(0.7) : .clear, radius: 5)
                                .offset(y: i == 2 ? animBall * 55 : 0)
                        }
                    }
                    .offset(y: -22)
                }
                .frame(width: 64, height: 90)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(mode.emoji)
                            .font(.system(size: 22))
                        Text(mode.title)
                            .font(RTheme.rounded(20, weight: .bold))
                            .foregroundStyle(RTheme.gold)
                            .tracking(2)
                    }

                    Text(mode.instruction)
                        .font(RTheme.mono(11))
                        .foregroundStyle(RTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)

                    HStack(spacing: 6) {
                        Label("3 lives", systemImage: "heart.fill")
                            .font(RTheme.mono(9, weight: .medium))
                            .foregroundStyle(RTheme.red.opacity(0.85))
                        Text("•")
                            .foregroundStyle(RTheme.faint)
                        Text("speed escalates")
                            .font(RTheme.mono(9))
                            .foregroundStyle(RTheme.faint)
                    }
                }

                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RTheme.bg)
                    .frame(width: 36, height: 36)
                    .background(RTheme.gold)
                    .clipShape(Circle())
            }
            .padding(RTheme.padSm)
            .background(
                LinearGradient(
                    colors: [RTheme.surface, RTheme.gold.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: RTheme.radius))
            .overlay(
                RoundedRectangle(cornerRadius: RTheme.radius)
                    .stroke(RTheme.gold.opacity(0.25), lineWidth: 1)
            )
            .scaleEffect(pressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeIn(duration: 0.07)) { pressed = true } }
                .onEnded   { _ in withAnimation(.easeOut(duration: 0.15)) { pressed = false } }
        )
        .onAppear {
            withAnimation(.easeIn(duration: 1.4).repeatForever(autoreverses: false)) {
                animBall = 1.0
            }
        }
    }
}
