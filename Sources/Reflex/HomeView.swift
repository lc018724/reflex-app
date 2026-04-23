import SwiftUI

struct HomeView: View {
    let onSelect: (TestMode) -> Void

    private let store = TestStore()
    @State private var overallBest: Double? = nil
    @State private var completedCount: Int = 0
    @State private var showSettings = false
    @State private var showRankings = false
    @State private var historyMode: TestMode? = nil
    @State private var streakMilestone: Int? = nil
    @State private var dailyCountdown: String = ""
    @State private var countdownTimer: Timer? = nil

    // Group modes by tier
    private let tiers: [(String, [TestMode])] = [
        ("SPEED",     [.flash, .fallingBall, .antiTap, .doubleFlash]),
        ("ATTENTION", [.find, .colorTap, .oddOneOut, .peripheral]),
        ("COGNITION", [.stroop, .reverseStroop, .mirror, .goNoGo]),
        ("MEMORY",    [.math, .sequence, .nBack, .digitMatch]),
        ("EXPERT",    [.simon, .speedSort, .rhythm, .dualTrack]),
    ]

    private let arcadeModes: [TestMode] = [.dropArcade, .whackArcade, .chainArcade, .gridArcade, .avoidArcade]

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // Hero
                    heroSection

                    // Daily challenge
                    dailyChallengeCard
                        .padding(.horizontal, RTheme.pad)
                        .padding(.bottom, 24)

                    // Insights (if enough data)
                    if completedCount >= 4 {
                        insightsSection
                            .padding(.bottom, 24)
                    }

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

            // Streak milestone toast
            if let ms = streakMilestone {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Text("🔥")
                            .font(.system(size: 24))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(ms)-DAY STREAK!")
                                .font(RTheme.mono(12, weight: .black))
                                .foregroundStyle(RTheme.gold)
                                .tracking(2)
                            Text("Keep it going!")
                                .font(RTheme.mono(10))
                                .foregroundStyle(RTheme.muted)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(RTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: RTheme.radius))
                    .overlay(RoundedRectangle(cornerRadius: RTheme.radius).stroke(RTheme.gold.opacity(0.4), lineWidth: 1))
                    .shadow(color: RTheme.gold.opacity(0.2), radius: 12)
                    .padding(.horizontal, RTheme.pad)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.4), value: streakMilestone)
            }
        }
        .onAppear {
            loadStats()
            startCountdownTimer()
        }
        .sheet(isPresented: $showSettings, onDismiss: loadStats) {
            SettingsView { showSettings = false }
        }
        .sheet(isPresented: $showRankings, onDismiss: loadStats) {
            RankingsView { showRankings = false }
        }
        .sheet(item: $historyMode) { mode in
            ModeHistoryView(mode: mode) { historyMode = nil }
        }
    }

    private func startCountdownTimer() {
        updateCountdown()
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateCountdown()
        }
    }

    private func updateCountdown() {
        let cal = Calendar.current
        guard let midnight = cal.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime) else { return }
        let secs = Int(midnight.timeIntervalSinceNow)
        let h = secs / 3600, m = (secs % 3600) / 60, s = secs % 60
        dailyCountdown = String(format: "%d:%02d:%02d", h, m, s)
    }

    private func loadStats() {
        let bests = TestMode.allCases.compactMap { store.bestMS(for: $0) }
        overallBest = bests.min()
        completedCount = bests.count

        // Check for streak milestone
        let streak = store.streak
        let milestones = [3, 7, 14, 30, 60, 100]
        if milestones.contains(streak) {
            let shownKey = "shownStreak_\(streak)"
            if !UserDefaults.standard.bool(forKey: shownKey) {
                UserDefaults.standard.set(true, forKey: shownKey)
                withAnimation { streakMilestone = streak }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { streakMilestone = nil }
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 0) {
            // Top row: spacer + rankings + gear
            HStack {
                Spacer()
                Button {
                    showRankings = true
                } label: {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(RTheme.muted)
                        .frame(width: 36, height: 36)
                        .background(RTheme.surface)
                        .clipShape(Circle())
                }
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(RTheme.muted)
                        .frame(width: 36, height: 36)
                        .background(RTheme.surface)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, RTheme.pad)
            .padding(.top, 56)

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
            .padding(.top, 8)

            // Stats row
            HStack(spacing: 0) {
                heroStat(label: "SESSIONS", value: "\(store.totalSessions)")
                Divider().overlay(RTheme.faint).frame(height: 28)
                heroStat(label: "DONE", value: "\(completedCount)/21")
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

            // Progress bar
            if completedCount > 0 {
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(RTheme.faint.opacity(0.3))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(RTheme.gold)
                                .frame(width: geo.size.width * CGFloat(completedCount) / 21.0, height: 4)
                                .animation(.spring(response: 0.5), value: completedCount)
                        }
                    }
                    .frame(height: 4)
                    Text("\(completedCount) of 21 tests completed")
                        .font(RTheme.mono(9))
                        .foregroundStyle(RTheme.faint)
                        .tracking(1)
                }
                .padding(.top, 14)
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

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "brain")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(red: 0.55, green: 0.35, blue: 0.95))
                Text("INSIGHTS")
                    .font(RTheme.mono(10, weight: .bold))
                    .foregroundStyle(RTheme.muted)
                    .tracking(4)
                Rectangle()
                    .fill(RTheme.faint)
                    .frame(height: 1)
            }
            .padding(.horizontal, RTheme.pad)

            let nonArcade = TestMode.allCases.filter { !$0.isArcade }
            let scored = nonArcade.compactMap { mode -> (TestMode, Double)? in
                guard let ms = store.bestMS(for: mode) else { return nil }
                return (mode, ms)
            }
            let sorted = scored.sorted { $0.1 < $1.1 }

            // Most improved: mode where last session avg is best vs all-time best
            let trending = nonArcade.compactMap { mode -> (TestMode, Double)? in
                let hist = store.history(for: mode)
                guard hist.count >= 2, let best = store.bestMS(for: mode) else { return nil }
                let lastSession = hist.last!
                let improvement = lastSession - best   // negative = improved (lower is better)
                guard improvement < 0 else { return nil }
                return (mode, abs(improvement))
            }.max(by: { $0.1 < $1.1 })

            if sorted.count >= 3 {
                HStack(spacing: 12) {
                    if let strongest = sorted.first {
                        insightCard(icon: "bolt.fill", label: "STRENGTH",
                                    modeName: strongest.0.title, ms: strongest.1, color: RTheme.green)
                    }
                    if let weakest = sorted.last {
                        insightCard(icon: "arrow.up.circle", label: "IMPROVE",
                                    modeName: weakest.0.title, ms: weakest.1, color: RTheme.red)
                    }
                }
                .padding(.horizontal, RTheme.pad)
                if let trend = trending {
                    HStack {
                        insightCard(icon: "chart.line.uptrend.xyaxis", label: "TRENDING UP",
                                    modeName: trend.0.title, ms: trend.1, color: Color(red: 0.55, green: 0.35, blue: 0.95),
                                    suffix: "ms drop last session")
                        Spacer()
                    }
                    .padding(.horizontal, RTheme.pad)
                }
            } else {
                HStack(spacing: 12) {
                    if let strongest = sorted.first {
                        insightCard(icon: "bolt.fill", label: "STRENGTH",
                                    modeName: strongest.0.title, ms: strongest.1, color: RTheme.green)
                    }
                    if let weakest = sorted.last, sorted.count > 1 {
                        insightCard(icon: "arrow.up.circle", label: "IMPROVE",
                                    modeName: weakest.0.title, ms: weakest.1, color: RTheme.red)
                    }
                }
                .padding(.horizontal, RTheme.pad)
            }
        }
        .padding(.bottom, 4)
    }

    private func insightCard(icon: String, label: String, modeName: String, ms: Double, color: Color, suffix: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                Text(label)
                    .font(RTheme.mono(9, weight: .bold))
                    .foregroundStyle(color)
                    .tracking(2)
            }
            Text(modeName)
                .font(RTheme.rounded(15, weight: .bold))
                .foregroundStyle(RTheme.white)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(String(format: "%.0f", ms))
                    .font(RTheme.mono(22, weight: .bold))
                    .foregroundStyle(color)
                Text(suffix ?? "ms")
                    .font(RTheme.mono(10))
                    .foregroundStyle(RTheme.muted)
            }
        }
        .padding(RTheme.padSm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
        .overlay(
            RoundedRectangle(cornerRadius: RTheme.radiusSm)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Daily Challenge

    private var dailyMode: TestMode {
        // Seeded by day-of-year so it's deterministic per day
        let allModes = TestMode.allCases.filter { !$0.isArcade }
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return allModes[dayOfYear % allModes.count]
    }

    private var dailyChallengeCard: some View {
        let mode = dailyMode
        let best = store.bestMS(for: mode)
        let isCompleted = best != nil

        return Button {
            onSelect(mode)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(RTheme.gold.opacity(isCompleted ? 0.15 : 0.1))
                        .frame(width: 52, height: 52)
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(RTheme.gold)
                    } else {
                        Text(mode.emoji)
                            .font(.system(size: 26))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("DAILY CHALLENGE")
                            .font(RTheme.mono(9, weight: .bold))
                            .foregroundStyle(RTheme.gold.opacity(0.85))
                            .tracking(2)
                        if isCompleted {
                            Text("DONE")
                                .font(RTheme.mono(8, weight: .bold))
                                .foregroundStyle(RTheme.bg)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(RTheme.green)
                                .clipShape(Capsule())
                        }
                    }
                    Text(mode.title)
                        .font(RTheme.rounded(17, weight: .bold))
                        .foregroundStyle(RTheme.white)
                    Text(mode.subtitle)
                        .font(RTheme.mono(10))
                        .foregroundStyle(RTheme.muted)
                    if isCompleted && !dailyCountdown.isEmpty {
                        Text("Next: \(dailyCountdown)")
                            .font(RTheme.mono(9))
                            .foregroundStyle(RTheme.faint)
                            .monospacedDigit()
                    }
                }

                Spacer()

                if let ms = best {
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f", ms))
                            .font(RTheme.mono(20, weight: .bold))
                            .foregroundStyle(speedColor(ms))
                        Text("ms")
                            .font(RTheme.mono(9))
                            .foregroundStyle(RTheme.faint)
                    }
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RTheme.gold.opacity(0.7))
                }
            }
            .padding(RTheme.padSm)
            .background(
                LinearGradient(
                    colors: [RTheme.surface, RTheme.gold.opacity(0.07)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: RTheme.radius))
            .overlay(
                RoundedRectangle(cornerRadius: RTheme.radius)
                    .stroke(RTheme.gold.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tier section

    private func tierSection(title: String, modes: [TestMode]) -> some View {
        let completedInTier = modes.filter { store.bestMS(for: $0) != nil }.count
        let tierColor = tierAccentColor(title)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(tierColor)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(RTheme.mono(10, weight: .bold))
                    .foregroundStyle(RTheme.muted)
                    .tracking(4)
                Rectangle()
                    .fill(RTheme.faint)
                    .frame(height: 1)
                Text("\(completedInTier)/\(modes.count)")
                    .font(RTheme.mono(9))
                    .foregroundStyle(completedInTier == modes.count ? RTheme.green : RTheme.faint)
                    .tracking(1)
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
                    .contextMenu {
                        if store.bestMS(for: mode) != nil {
                            Button {
                                historyMode = mode
                            } label: {
                                Label("View History", systemImage: "chart.line.uptrend.xyaxis")
                            }
                        }
                        Button {
                            onSelect(mode)
                        } label: {
                            Label("Play", systemImage: "play.fill")
                        }
                    }
                }
            }
            .padding(.horizontal, RTheme.pad)
        }
        .padding(.bottom, 20)
    }

    private func tierAccentColor(_ tier: String) -> Color {
        switch tier {
        case "SPEED":     return RTheme.gold
        case "ATTENTION": return RTheme.green
        case "COGNITION": return Color(red: 0.55, green: 0.35, blue: 0.95)
        case "MEMORY":    return Color(red: 0.30, green: 0.70, blue: 0.95)
        case "EXPERT":    return RTheme.red
        default:          return RTheme.muted
        }
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
    private let store = TestStore()

    private var trendArrow: (up: Bool, show: Bool) {
        let hist = store.history(for: mode)
        guard hist.count >= 2 else { return (false, false) }
        let improved = hist.last! < hist[hist.count - 2]
        return (improved, true)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left tier-color accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(tierEdgeColor)
                    .frame(width: 3)
                    .padding(.leading, 8)
                    .padding(.vertical, 10)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(mode.emoji)
                            .font(.system(size: 22))
                        Spacer()
                        if let ms = best {
                            HStack(spacing: 3) {
                                let trend = trendArrow
                                if trend.show {
                                    Image(systemName: trend.up ? "arrow.down" : "arrow.up")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(trend.up ? RTheme.green : RTheme.red)
                                }
                                Text(String(format: "%.0f", ms))
                                    .font(RTheme.mono(13, weight: .bold))
                                    .foregroundStyle(msColor(ms))
                            }
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
            }
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

    private var tierEdgeColor: Color {
        switch mode.tier {
        case 1: return RTheme.gold
        case 2: return RTheme.green
        case 3: return Color(red: 0.55, green: 0.35, blue: 0.95)
        case 4: return Color(red: 0.30, green: 0.70, blue: 0.95)
        case 5: return RTheme.red
        default: return RTheme.faint
        }
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
    @State private var animTargets: [CGFloat] = [0, 0, 0]
    @State private var gridActiveCell: Int = -1
    @State private var avoidBallOffset: CGPoint = .zero
    @State private var avoidRingScale: CGFloat = 0

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Animated mini preview — differs per mode
                arcadePreview
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
            if mode == .dropArcade {
                withAnimation(.easeIn(duration: 1.4).repeatForever(autoreverses: false)) {
                    animBall = 1.0
                }
            } else if mode == .whackArcade {
                startWhackPreviewAnimation()
            } else if mode == .chainArcade {
                startChainPreviewAnimation()
            } else if mode == .gridArcade {
                startGridPreviewAnimation()
            } else if mode == .avoidArcade {
                startAvoidPreviewAnimation()
            }
        }
    }

    // MARK: - Mode-specific preview animations

    @ViewBuilder
    private var arcadePreview: some View {
        ZStack {
            RTheme.bg
                .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))

            if mode == .dropArcade {
                dropPreview
            } else if mode == .whackArcade {
                whackPreview
            } else if mode == .chainArcade {
                chainPreview
            } else if mode == .gridArcade {
                gridPreview
            } else if mode == .avoidArcade {
                avoidPreview
            }
        }
    }

    private var dropPreview: some View {
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

    private let whackColors: [Color] = [RTheme.gold, RTheme.green, RTheme.red]
    private let whackPositions: [(CGFloat, CGFloat)] = [(0.3, 0.2), (0.7, 0.55), (0.35, 0.78)]

    private var whackPreview: some View {
        GeometryReader { geo in
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.7), whackColors[i]],
                            center: .center,
                            startRadius: 1,
                            endRadius: 8
                        )
                    )
                    .frame(width: 16, height: 16)
                    .shadow(color: whackColors[i].opacity(0.9), radius: 6)
                    .scaleEffect(animTargets[i])
                    .opacity(animTargets[i])
                    .position(
                        x: whackPositions[i].0 * geo.size.width,
                        y: whackPositions[i].1 * geo.size.height
                    )
            }
        }
    }

    private let chainPositions: [(CGFloat, CGFloat)] = [(0.35, 0.25), (0.65, 0.5), (0.35, 0.75)]

    private func startWhackPreviewAnimation() {
        let delays = [0.0, 0.45, 0.9]
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delays[i]) {
                withAnimation(.easeInOut(duration: 0.3)) { animTargets[i] = 1.0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeIn(duration: 0.25)) { animTargets[i] = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false).delay(delays[i])) {
                            animTargets[i] = 1.0
                        }
                    }
                }
            }
        }
    }

    private var chainPreview: some View {
        GeometryReader { geo in
            ForEach(0..<3, id: \.self) { i in
                ZStack {
                    Circle()
                        .stroke(i == 0 ? RTheme.gold : RTheme.faint, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    Text("\(i + 1)")
                        .font(RTheme.mono(9, weight: .black))
                        .foregroundStyle(i == 0 ? RTheme.gold : RTheme.white.opacity(0.5))
                }
                .scaleEffect(animTargets[i])
                .opacity(animTargets[i])
                .position(
                    x: chainPositions[i].0 * geo.size.width,
                    y: chainPositions[i].1 * geo.size.height
                )
            }
        }
    }

    private var gridPreview: some View {
        GeometryReader { geo in
            let cellSize: CGFloat = 13
            let gap: CGFloat = 4
            let gridSize = cellSize * 4 + gap * 3
            let hOff = (geo.size.width - gridSize) / 2
            let vOff = (geo.size.height - gridSize) / 2

            ForEach(0..<16, id: \.self) { i in
                let row = i / 4
                let col = i % 4
                RoundedRectangle(cornerRadius: 3)
                    .fill(i == gridActiveCell ? RTheme.gold : RTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(i == gridActiveCell ? RTheme.gold : RTheme.faint.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: i == gridActiveCell ? RTheme.gold.opacity(0.7) : .clear, radius: 5)
                    .frame(width: cellSize, height: cellSize)
                    .scaleEffect(i == gridActiveCell ? 1.15 : 1.0)
                    .animation(.spring(response: 0.2), value: gridActiveCell)
                    .position(
                        x: hOff + cellSize / 2 + CGFloat(col) * (cellSize + gap),
                        y: vOff + cellSize / 2 + CGFloat(row) * (cellSize + gap)
                    )
            }
        }
    }

    private func startChainPreviewAnimation() {
        let delays = [0.0, 0.3, 0.6]
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delays[i]) {
                withAnimation(.spring(response: 0.3)) { animTargets[i] = 1.0 }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                    withAnimation(.easeIn(duration: 0.2)) { animTargets[i] = 0 }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                startChainPreviewAnimation()
            }
        }
    }

    private func startGridPreviewAnimation() {
        func flash() {
            let next = Int.random(in: 0..<16)
            withAnimation(.easeIn(duration: 0.1)) { gridActiveCell = next }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeOut(duration: 0.1)) { gridActiveCell = -1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { flash() }
            }
        }
        flash()
    }

    private var avoidPreview: some View {
        GeometryReader { geo in
            ZStack {
                // Danger ball (red)
                Circle()
                    .fill(RTheme.red.opacity(0.85))
                    .frame(width: 14, height: 14)
                    .shadow(color: RTheme.red.opacity(0.6), radius: 4)
                    .position(
                        x: geo.size.width / 2 + avoidBallOffset.x,
                        y: geo.size.height / 2 + avoidBallOffset.y
                    )
                // Ring target (gold)
                ZStack {
                    Circle()
                        .stroke(RTheme.gold.opacity(0.4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    Circle()
                        .fill(RTheme.gold.opacity(0.1))
                        .frame(width: 18, height: 18)
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(RTheme.gold)
                }
                .scaleEffect(avoidRingScale)
                .opacity(avoidRingScale)
                .position(x: geo.size.width * 0.7, y: geo.size.height * 0.3)
            }
        }
    }

    private func startAvoidPreviewAnimation() {
        // Animate the danger ball bouncing
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            avoidBallOffset = CGPoint(x: 18, y: -15)
        }
        // Ring pops in and out
        func ringCycle() {
            withAnimation(.spring(response: 0.2)) { avoidRingScale = 1.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeIn(duration: 0.2)) { avoidRingScale = 0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { ringCycle() }
            }
        }
        ringCycle()
    }
}
