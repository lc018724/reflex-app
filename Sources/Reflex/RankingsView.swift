import SwiftUI

// MARK: - Rankings View
// Shows all 20 cognitive modes ranked by personal best time (lower = better).
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
                            // Cognitive profile (tier radar + bars)
                            cognitiveProfileSection

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
                                            Text("-")
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

    // MARK: - Tier profile

    private let tierConfig: [(String, [TestMode], Color)] = [
        ("SPEED",     [.flash, .fallingBall, .antiTap, .doubleFlash],   Color(red: 1.0,  green: 0.35, blue: 0.35)),
        ("ATTENTION", [.find, .colorTap, .oddOneOut, .peripheral],      Color(red: 1.0,  green: 0.75, blue: 0.2)),
        ("COGNITION", [.stroop, .reverseStroop, .mirror, .goNoGo],      Color(red: 0.3,  green: 0.75, blue: 1.0)),
        ("MEMORY",    [.math, .sequence, .nBack, .digitMatch],           Color(red: 0.55, green: 0.85, blue: 0.45)),
        ("EXPERT",    [.simon, .speedSort, .rhythm, .dualTrack],         Color(red: 0.75, green: 0.4,  blue: 1.0)),
    ]

    /// Normalize an ms score to 0...1 where 1 = best (fastest ~150ms) and 0 = slow (400ms+).
    private func normalizeScore(_ ms: Double) -> Double {
        let best: Double = 150, worst: Double = 400
        return max(0, min(1, (worst - ms) / (worst - best)))
    }

    private var tierScores: [(label: String, score: Double, color: Color)] {
        tierConfig.compactMap { label, modes, color in
            let bests = modes.compactMap { store.bestMS(for: $0) }
            guard !bests.isEmpty else { return nil }
            let avg = bests.reduce(0, +) / Double(bests.count)
            return (label, normalizeScore(avg), color)
        }
    }

    private var cognitiveProfileSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "hexagon.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(red: 0.55, green: 0.35, blue: 0.95))
                Text("COGNITIVE PROFILE")
                    .font(RTheme.mono(9, weight: .bold))
                    .foregroundStyle(RTheme.muted)
                    .tracking(4)
                Rectangle().fill(RTheme.faint).frame(height: 1)
            }

            let scores = tierScores
            if scores.count >= 3 {
                HStack(alignment: .top, spacing: 16) {
                    RadarChartView(scores: scores.map { $0.score })
                        .frame(width: 140, height: 140)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(scores.enumerated()), id: \.0) { _, item in
                            tierScoreRow(label: item.label, score: item.score, color: item.color)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(RTheme.padSm)
                .background(RTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: RTheme.radius))
            } else {
                Text("Complete at least 3 tiers to see your cognitive profile")
                    .font(RTheme.mono(10))
                    .foregroundStyle(RTheme.faint)
                    .padding(RTheme.padSm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: RTheme.radius))
            }
        }
    }

    private func tierScoreRow(label: String, score: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(RTheme.mono(9, weight: .bold))
                .foregroundStyle(RTheme.muted)
                .tracking(2)
                .frame(width: 68, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(RTheme.faint.opacity(0.4)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(color)
                        .frame(width: geo.size.width * score, height: 4)
                }
            }
            .frame(height: 4)
            Text(String(format: "%.0f%%", score * 100))
                .font(RTheme.mono(9, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 30, alignment: .trailing)
        }
    }


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

// MARK: - Radar Chart

private struct RadarChartView: View {
    let scores: [Double]  // 0...1 per axis (up to 5)

    private func point(index: Int, value: Double, in rect: CGRect) -> CGPoint {
        let n = scores.count
        let angle = (2 * Double.pi / Double(n)) * Double(index) - Double.pi / 2
        let cx = rect.midX, cy = rect.midY
        let r = min(rect.width, rect.height) / 2 * 0.82
        return CGPoint(x: cx + r * value * cos(angle), y: cy + r * value * sin(angle))
    }

    private func gridPoint(index: Int, scale: Double, in rect: CGRect) -> CGPoint {
        point(index: index, value: scale, in: rect)
    }

    var body: some View {
        Canvas { ctx, size in
            let rect = CGRect(origin: .zero, size: size)
            let n = scores.count
            guard n >= 3 else { return }
            let cx = rect.midX, cy = rect.midY

            // Grid rings
            for ring in 1...4 {
                let scale = Double(ring) / 4.0
                var gridPath = Path()
                for i in 0..<n {
                    let pt = gridPoint(index: i, scale: scale, in: rect)
                    if i == 0 { gridPath.move(to: pt) } else { gridPath.addLine(to: pt) }
                }
                gridPath.closeSubpath()
                ctx.stroke(gridPath, with: .color(.white.opacity(0.06)), lineWidth: 1)
            }

            // Spokes
            for i in 0..<n {
                var spoke = Path()
                spoke.move(to: CGPoint(x: cx, y: cy))
                spoke.addLine(to: gridPoint(index: i, scale: 1.0, in: rect))
                ctx.stroke(spoke, with: .color(.white.opacity(0.08)), lineWidth: 1)
            }

            // Filled polygon
            var fillPath = Path()
            for (i, score) in scores.enumerated() {
                let pt = point(index: i, value: max(0.05, score), in: rect)
                if i == 0 { fillPath.move(to: pt) } else { fillPath.addLine(to: pt) }
            }
            fillPath.closeSubpath()
            ctx.fill(fillPath, with: .color(Color(red: 0.55, green: 0.35, blue: 0.95).opacity(0.25)))
            ctx.stroke(fillPath, with: .color(Color(red: 0.55, green: 0.35, blue: 0.95).opacity(0.8)), lineWidth: 2)

            // Dot at each vertex
            for (i, score) in scores.enumerated() {
                let pt = point(index: i, value: max(0.05, score), in: rect)
                let dot = Path(ellipseIn: CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6))
                ctx.fill(dot, with: .color(Color(red: 0.55, green: 0.35, blue: 0.95)))
            }
        }
    }
}
