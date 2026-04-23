import SwiftUI

// MARK: - Rankings View
// Shows all 21 cognitive modes ranked by personal best time (lower = better).
// Accessible via "RANKINGS" button in HomeView.

struct RankingsView: View {
    let onDismiss: () -> Void
    private let store = TestStore()

    private var rankedModes: [(TestMode, Double)] {
        let nonArcade = TestMode.allCases.filter { !$0.isArcade }
        let ranked = nonArcade.compactMap { mode -> (TestMode, Double)? in
            guard let best = store.bestMS(for: mode) else { return nil }
            return (mode, best)
        }
        return ranked.sorted { $0.1 < $1.1 }
    }

    private var unplayed: [TestMode] {
        TestMode.allCases.filter { !$0.isArcade && store.bestMS(for: $0) == nil }
    }

    var body: some View {
        ZStack {
            RTheme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("🏆 RANKINGS")
                            .font(RTheme.rounded(20, weight: .bold))
                            .foregroundStyle(RTheme.white)
                        Text("Ranked by personal best")
                            .font(RTheme.mono(10))
                            .foregroundStyle(RTheme.muted)
                    }
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(RTheme.muted)
                            .frame(width: 32, height: 32)
                            .background(RTheme.surface)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, RTheme.pad)
                .padding(.top, 24)
                .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        if rankedModes.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "trophy")
                                    .font(.system(size: 48))
                                    .foregroundStyle(RTheme.faint)
                                Text("No results yet")
                                    .font(RTheme.mono(15, weight: .medium))
                                    .foregroundStyle(RTheme.muted)
                                Text("Complete tests to see your rankings")
                                    .font(RTheme.mono(11))
                                    .foregroundStyle(RTheme.faint)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 60)
                        } else {
                            // Top 3 podium
                            if rankedModes.count >= 3 {
                                podiumSection
                                    .padding(.bottom, 8)
                            }

                            // Full ranked list
                            VStack(spacing: 0) {
                                ForEach(Array(rankedModes.enumerated()), id: \.0) { i, item in
                                    let (mode, ms) = item
                                    rankRow(rank: i + 1, mode: mode, ms: ms)
                                    if i < rankedModes.count - 1 {
                                        Divider().overlay(RTheme.faint).padding(.leading, 56)
                                    }
                                }
                            }
                            .background(RTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: RTheme.radius))
                        }

                        // Unplayed modes
                        if !unplayed.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("NOT YET ATTEMPTED")
                                    .font(RTheme.mono(9, weight: .bold))
                                    .foregroundStyle(RTheme.faint)
                                    .tracking(3)
                                    .padding(.bottom, 8)
                                    .padding(.horizontal, 4)

                                VStack(spacing: 0) {
                                    ForEach(Array(unplayed.enumerated()), id: \.0) { i, mode in
                                        HStack(spacing: 12) {
                                            Text(mode.emoji)
                                                .font(.system(size: 16))
                                            Text(mode.title)
                                                .font(RTheme.rounded(14))
                                                .foregroundStyle(RTheme.faint)
                                            Spacer()
                                            Text("—")
                                                .font(RTheme.mono(12))
                                                .foregroundStyle(RTheme.faint)
                                        }
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, RTheme.padSm)
                                        if i < unplayed.count - 1 {
                                            Divider().overlay(RTheme.faint)
                                        }
                                    }
                                }
                                .background(RTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: RTheme.radius))
                            }
                        }
                    }
                    .padding(.horizontal, RTheme.pad)
                    .padding(.bottom, 60)
                }
            }
        }
    }

    // MARK: - Podium

    private var podiumSection: some View {
        let medals = ["🥇", "🥈", "🥉"]
        let medalColors: [Color] = [RTheme.gold, Color(white: 0.75), Color(red: 0.8, green: 0.5, blue: 0.2)]

        return HStack(alignment: .bottom, spacing: 8) {
            ForEach([1, 0, 2], id: \.self) { idx in
                if idx < rankedModes.count {
                    let (mode, ms) = rankedModes[idx]
                    podiumCard(
                        medal: medals[idx],
                        mode: mode,
                        ms: ms,
                        color: medalColors[idx],
                        height: idx == 0 ? 110 : (idx == 1 ? 90 : 75)
                    )
                }
            }
        }
    }

    private func podiumCard(medal: String, mode: TestMode, ms: Double, color: Color, height: CGFloat) -> some View {
        VStack(spacing: 6) {
            Text(medal)
                .font(.system(size: 22))
            Text(mode.emoji)
                .font(.system(size: 18))
            Text(mode.title)
                .font(RTheme.mono(8, weight: .bold))
                .foregroundStyle(RTheme.white)
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(String(format: "%.0fms", ms))
                .font(RTheme.mono(12, weight: .black))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
        .overlay(
            RoundedRectangle(cornerRadius: RTheme.radiusSm)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Row

    private func rankRow(rank: Int, mode: TestMode, ms: Double) -> some View {
        HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankBg(rank))
                    .frame(width: 32, height: 32)
                Text(rankEmoji(rank) ?? "\(rank)")
                    .font(rank <= 3 ? .system(size: 14) : RTheme.mono(11, weight: .bold))
                    .foregroundStyle(rankFg(rank))
            }

            Text(mode.emoji)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text(mode.title)
                    .font(RTheme.rounded(14, weight: .semibold))
                    .foregroundStyle(RTheme.white)
                Text(mode.subtitle)
                    .font(RTheme.mono(9))
                    .foregroundStyle(RTheme.faint)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0fms", ms))
                    .font(RTheme.mono(14, weight: .bold))
                    .foregroundStyle(msColor(ms))
                Text(speedLabel(ms))
                    .font(RTheme.mono(8))
                    .foregroundStyle(msColor(ms).opacity(0.6))
                    .tracking(1)
            }
        }
        .padding(.horizontal, RTheme.padSm)
        .padding(.vertical, 12)
    }

    private func rankBg(_ rank: Int) -> Color {
        switch rank {
        case 1: return RTheme.gold.opacity(0.2)
        case 2: return Color(white: 0.75).opacity(0.15)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2).opacity(0.15)
        default: return RTheme.bg
        }
    }

    private func rankFg(_ rank: Int) -> Color {
        switch rank {
        case 1: return RTheme.gold
        case 2: return Color(white: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return RTheme.faint
        }
    }

    private func rankEmoji(_ rank: Int) -> String? {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return nil
        }
    }

    private func msColor(_ ms: Double) -> Color {
        switch ms {
        case ..<200: return RTheme.green
        case 200..<270: return RTheme.gold
        default: return RTheme.red
        }
    }

    private func speedLabel(_ ms: Double) -> String {
        switch ms {
        case ..<175: return "ELITE"
        case 175..<200: return "EXCELLENT"
        case 200..<230: return "GREAT"
        case 230..<270: return "AVERAGE"
        case 270..<320: return "SLOW"
        default: return "SLUGGISH"
        }
    }
}
