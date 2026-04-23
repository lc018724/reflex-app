import SwiftUI

struct HomeView: View {
    let onSelect: (TestMode) -> Void

    private let store = TestStore()
    @State private var overallBest: Double? = nil

    // Group modes by tier
    private let tiers: [(String, [TestMode])] = [
        ("SPEED",     [.flash, .fallingBall, .antiTap, .doubleFlash]),
        ("ATTENTION", [.find, .colorTap, .oddOneOut, .peripheral]),
        ("COGNITION", [.stroop, .reverseStroop, .mirror, .goNoGo]),
        ("MEMORY",    [.math, .sequence, .nBack, .digitMatch]),
        ("EXPERT",    [.simon, .speedSort, .rhythm, .dualTrack]),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // Hero
                heroSection

                // Tier groups
                ForEach(tiers, id: \.0) { tierName, modes in
                    tierSection(title: tierName, modes: modes)
                }

                benchmarkFooter
                    .padding(.top, 20)
                    .padding(.bottom, 60)
            }
        }
        .onAppear {
            let bests = TestMode.allCases.compactMap { store.bestMS(for: $0) }
            overallBest = bests.min()
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 10) {
            Text("REFLEX")
                .font(RTheme.serif(52, weight: .black))
                .foregroundStyle(RTheme.gold)
                .tracking(12)

            Text("20 cognitive challenges")
                .font(RTheme.mono(12))
                .foregroundStyle(RTheme.muted)
                .tracking(2)

            if let ms = overallBest {
                bestBadge(ms: ms)
                    .padding(.top, 12)
            } else {
                Text("Complete a test to establish your baseline")
                    .font(RTheme.mono(12))
                    .foregroundStyle(RTheme.faint)
                    .padding(.top, 12)
            }
        }
        .padding(.top, 60)
        .padding(.bottom, 32)
        .padding(.horizontal, RTheme.pad)
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
        VStack(spacing: 4) {
            Text("Average: 200-250ms  •  F1 driver: 150ms")
                .font(RTheme.mono(10))
                .foregroundStyle(RTheme.faint)
            Text("Impaired driver: 300ms+  •  Elite athlete: <175ms")
                .font(RTheme.mono(10))
                .foregroundStyle(RTheme.faint)
        }
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
