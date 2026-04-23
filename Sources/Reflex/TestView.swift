import SwiftUI
import UIKit

struct TestView: View {
    @ObservedObject var engine: TestEngine
    let mode: TestMode
    let onDismiss: () -> Void

    private let store = TestStore()
    private let impactLight  = UIImpactFeedbackGenerator(style: .light)
    private let impactHeavy  = UIImpactFeedbackGenerator(style: .heavy)
    private let notif        = UINotificationFeedbackGenerator()

    @State private var bgFlash: Color = RTheme.bg
    @State private var suppressTimer: Task<Void, Never>? = nil
    @State private var previousBest: Double? = nil
    @State private var trialsDone: Int = 0

    var body: some View {
        ZStack {
            bgFlash.ignoresSafeArea()
                .animation(.easeOut(duration: 0.07), value: bgFlash)

            VStack(spacing: 0) {
                // Top bar
                topBar

                Spacer()

                // Main content
                Group {
                    switch engine.phase {
                    case .idle:
                        Color.clear

                    case .instruction:
                        InstructionView(mode: mode) {
                            engine.dismissInstruction()
                        }

                    case .countdown(let n):
                        countdownView(n)

                    case .waiting:
                        waitingView

                    case .stimulus(let data):
                        StimulusRouter(data: data, mode: mode, engine: engine)
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))

                    case .tooSoon:
                        tooSoonView

                    case .result(let ms, let trial, let total, let isError):
                        resultMoment(ms: ms, trial: trial, total: total, isError: isError)

                    case .sequenceInput(let steps, let inputSoFar, let target):
                        SequenceInputView(steps: steps, inputSoFar: inputSoFar,
                                          targetSteps: target, engine: engine)

                    case .sessionDone(let avg, let best, let results):
                        SessionSummaryView(
                            mode: mode, avg: avg, best: best, results: results,
                            previousBest: previousBest,
                            onReplay: { engine.startSession(mode: mode) },
                            onHome: onDismiss
                        )
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: engine.phaseID)

                Spacer()
                Spacer()
            }
        }
        .onChange(of: engine.phaseID) { _ in
            handlePhaseChange(engine.phase)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(screenTapGesture)
        .onDisappear { suppressTimer?.cancel() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: 10) {
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
                Text(mode.title)
                    .font(RTheme.mono(13, weight: .medium))
                    .foregroundStyle(RTheme.muted)
                    .tracking(3)
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }

            // Trial progress dots
            if let (trial, total) = currentTrialProgress {
                HStack(spacing: 6) {
                    ForEach(0..<total, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < trial ? RTheme.gold : RTheme.faint)
                            .frame(width: i < trial ? 16 : 10, height: 4)
                            .animation(.spring(response: 0.25), value: trial)
                    }
                }
            } else if trialsDone > 0 {
                let total = mode.trialCount
                HStack(spacing: 6) {
                    ForEach(0..<total, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < trialsDone ? RTheme.gold : RTheme.faint)
                            .frame(width: i < trialsDone ? 16 : 10, height: 4)
                            .animation(.spring(response: 0.25), value: trialsDone)
                    }
                }
            }
        }
        .padding(.horizontal, RTheme.pad)
        .padding(.top, 56)
    }

    private var currentTrialProgress: (Int, Int)? {
        switch engine.phase {
        case .result(_, let trial, let total, _): return (trial, total)
        default: return nil
        }
    }

    private var isActiveTrial: Bool {
        switch engine.phase {
        case .waiting, .stimulus, .tooSoon, .countdown, .sequenceInput: return true
        default: return false
        }
    }

    // MARK: - Phase views

    private func countdownView(_ n: Int) -> some View {
        ZStack {
            // Countdown ring
            Circle()
                .stroke(RTheme.faint, lineWidth: 3)
                .frame(width: 120, height: 120)

            Circle()
                .trim(from: 0, to: n == 0 ? 0 : CGFloat(n) / 3.0)
                .stroke(n == 0 ? RTheme.muted : RTheme.gold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 120, height: 120)
                .animation(.easeOut(duration: 0.25), value: n)

            Text(n == 0 ? "GO" : "\(n)")
                .font(n == 0
                      ? RTheme.rounded(28, weight: .black)
                      : RTheme.mono(72, weight: .bold))
                .foregroundStyle(n == 0 ? RTheme.gold : RTheme.white)
                .contentTransition(.numericText())
        }
    }

    private var waitingView: some View {
        VStack(spacing: 24) {
            if mode == .peripheral {
                Text("WATCH THE EDGES")
                    .font(RTheme.mono(13, weight: .medium))
                    .foregroundStyle(RTheme.muted)
                    .tracking(4)
            }
            PulsingWaitDot()
        }
    }

    private var tooSoonView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(RTheme.red)
            Text("TOO SOON")
                .font(RTheme.mono(44, weight: .bold))
                .foregroundStyle(RTheme.red)
                .tracking(4)
            Text("Wait for the signal")
                .font(RTheme.mono(13))
                .foregroundStyle(RTheme.muted)
        }
    }

    private func resultMoment(ms: Double, trial: Int, total: Int, isError: Bool) -> some View {
        VStack(spacing: 20) {
            if isError {
                VStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(RTheme.red)
                    Text("WRONG")
                        .font(RTheme.mono(18, weight: .bold))
                        .foregroundStyle(RTheme.red)
                        .tracking(4)
                }
            } else {
                VStack(spacing: 6) {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(String(format: "%.0f", ms))
                            .font(.system(size: 80, weight: .bold, design: .monospaced))
                            .foregroundStyle(msColor(ms))
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.7).combined(with: .opacity),
                                removal: .opacity
                            ))
                        Text("ms")
                            .font(RTheme.mono(24))
                            .foregroundStyle(RTheme.muted)
                    }
                    // Contextual label
                    Text(speedLabel(ms))
                        .font(RTheme.mono(11, weight: .medium))
                        .foregroundStyle(msColor(ms).opacity(0.7))
                        .tracking(3)
                }
            }

            // Trial dots
            HStack(spacing: 8) {
                ForEach(0..<total, id: \.self) { i in
                    Circle()
                        .fill(i < trial ? (i == trial-1 && isError ? RTheme.red : RTheme.gold) : RTheme.faint)
                        .frame(width: 8, height: 8)
                        .animation(.easeIn(duration: 0.15), value: trial)
                }
            }
        }
    }

    // MARK: - Screen tap

    private var screenTapGesture: some Gesture {
        TapGesture().onEnded {
            switch engine.phase {
            case .waiting:
                // Only handle screen tap for modes that use full-screen input
                if [.flash, .antiTap, .goNoGo, .nBack, .peripheral].contains(mode) {
                    engine.handleTap()
                }
            case .stimulus:
                if [.flash, .antiTap, .peripheral].contains(mode) {
                    engine.handleTap()
                }
            default:
                break
            }
        }
    }

    // MARK: - Phase change side effects

    private func handlePhaseChange(_ phase: TestPhase) {
        switch phase {
        case .instruction:
            trialsDone = 0

        case .stimulus(let data):
            impactLight.impactOccurred()
            if case .flash = data {
                bgFlash = RTheme.gold
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { bgFlash = RTheme.bg }
            }
            if case .antiTap = data {
                bgFlash = RTheme.gold
            }

            // Auto-advance suppression
            switch data {
            case .goNoGo(let isGo) where !isGo:
                scheduleNoTap(delay: 1.5)
            case .nBack(_, let shouldTap) where !shouldTap:
                scheduleNoTap(delay: 1.5)
            default:
                break
            }

        case .result(let ms, let trial, _, let isError):
            suppressTimer?.cancel()
            bgFlash = RTheme.bg
            trialsDone = trial
            if isError {
                notif.notificationOccurred(.error)
            } else {
                impactHeavy.impactOccurred()
                // Subtle bg tint based on speed
                if ms < 200 {
                    bgFlash = RTheme.green.opacity(0.15)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { bgFlash = RTheme.bg }
                }
            }

        case .sessionDone(let avg, _, _):
            suppressTimer?.cancel()
            bgFlash = RTheme.bg
            trialsDone = 0
            if avg > 0 {
                previousBest = store.bestMS(for: mode)  // capture before overwrite
                store.updateBest(ms: avg, for: mode)
                store.appendSession(avg: avg, for: mode)
                store.totalSessions += 1
                store.recordSessionDay()
            }

        case .tooSoon:
            bgFlash = RTheme.bg
            notif.notificationOccurred(.warning)

        default:
            bgFlash = RTheme.bg
        }
    }

    private func scheduleNoTap(delay: Double) {
        suppressTimer?.cancel()
        suppressTimer = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            engine.handleNoTap()
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

// MARK: - Instruction View

struct InstructionView: View {
    let mode: TestMode
    let onStart: () -> Void

    private let store = TestStore()

    var body: some View {
        VStack(spacing: 28) {
            Text(mode.emoji)
                .font(.system(size: 64))
                .shadow(color: RTheme.gold.opacity(0.3), radius: 20)

            VStack(spacing: 10) {
                Text(mode.title)
                    .font(RTheme.serif(32, weight: .black))
                    .foregroundStyle(RTheme.gold)
                    .tracking(4)
                Text(mode.subtitle.uppercased())
                    .font(RTheme.mono(11))
                    .foregroundStyle(RTheme.muted)
                    .tracking(3)
            }

            Text(mode.instruction)
                .font(RTheme.mono(14))
                .foregroundStyle(RTheme.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 8)

            // Tier / difficulty badge
            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: i < mode.tier ? "star.fill" : "star")
                            .font(.system(size: 9))
                            .foregroundStyle(i < mode.tier ? tierColor(mode.tier) : RTheme.faint)
                    }
                }
                Text(tierName(mode.tier).uppercased())
                    .font(RTheme.mono(9, weight: .bold))
                    .foregroundStyle(tierColor(mode.tier))
                    .tracking(2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(tierColor(mode.tier).opacity(0.1))
            .clipShape(Capsule())

            // Personal best badge
            if let pb = store.bestMS(for: mode) {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(RTheme.gold)
                    Text("PERSONAL BEST  \(Int(pb))ms")
                        .font(RTheme.mono(11, weight: .bold))
                        .foregroundStyle(RTheme.gold)
                        .tracking(2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(RTheme.gold.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(RTheme.gold.opacity(0.3), lineWidth: 1))
            }

            GoldButton(label: "START", action: onStart, fullWidth: false)
                .padding(.top, 4)
        }
        .padding(.horizontal, 32)
    }

    private func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 1: return RTheme.gold
        case 2: return RTheme.green
        case 3: return Color(red: 0.55, green: 0.35, blue: 0.95)
        case 4: return Color(red: 0.30, green: 0.70, blue: 0.95)
        case 5: return RTheme.red
        default: return RTheme.faint
        }
    }

    private func tierName(_ tier: Int) -> String {
        switch tier {
        case 1: return "Beginner"
        case 2: return "Easy"
        case 3: return "Medium"
        case 4: return "Hard"
        case 5: return "Expert"
        default: return "?"
        }
    }
}

// MARK: - Session Summary

struct SessionSummaryView: View {
    let mode: TestMode
    let avg: Double
    let best: Double
    let results: [Double]
    let previousBest: Double?
    let onReplay: () -> Void
    let onHome: () -> Void

    private var isNewBest: Bool {
        guard avg > 0, let prev = previousBest else { return previousBest == nil && avg > 0 }
        return avg < prev
    }

    private var improvement: Double? {
        guard let prev = previousBest, avg > 0 else { return nil }
        return prev - avg  // positive = faster = better
    }

    private var validResults: [Double] { results.filter { $0 < 999 } }
    private var feet: Double { ReactionBenchmarks.drivingFeet(ms: avg) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {

                // Score
                VStack(spacing: 8) {
                    // New best banner
                    if isNewBest {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(RTheme.bg)
                            Text("NEW PERSONAL BEST!")
                                .font(RTheme.mono(11, weight: .bold))
                                .foregroundStyle(RTheme.bg)
                                .tracking(2)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(RTheme.gold)
                        .clipShape(Capsule())
                    }

                    Text("YOUR AVERAGE")
                        .font(RTheme.mono(10, weight: .medium))
                        .foregroundStyle(RTheme.muted)
                        .tracking(3)

                    if avg > 0 {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(String(format: "%.0f", avg))
                                .font(.system(size: 80, weight: .bold, design: .monospaced))
                                .foregroundStyle(msColor(avg))
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                            Text("ms")
                                .font(RTheme.mono(22))
                                .foregroundStyle(RTheme.muted)
                        }
                        Text(ReactionBenchmarks.label(ms: avg).uppercased())
                            .font(RTheme.rounded(13, weight: .bold))
                            .foregroundStyle(RTheme.gold)
                            .tracking(3)
                    } else {
                        Text("NO VALID RESULTS")
                            .font(RTheme.mono(20, weight: .bold))
                            .foregroundStyle(RTheme.red)
                    }
                }

                // Stats strip
                if avg > 0 {
                    HStack(spacing: 0) {
                        statCell("PERCENTILE", "TOP \(100 - ReactionBenchmarks.percentile(ms: avg))%")
                        Divider().overlay(RTheme.faint).frame(height: 40)
                        if let delta = improvement {
                            statCell("vs BEST", delta > 0
                                ? String(format: "+%.0fms", delta)
                                : String(format: "%.0fms", delta),
                                color: delta > 0 ? RTheme.green : RTheme.red)
                        } else {
                            statCell("BEST", String(format: "%.0fms", best))
                        }
                        Divider().overlay(RTheme.faint).frame(height: 40)
                        statCell("60MPH", String(format: "%.1f ft", feet))
                    }
                    .padding(RTheme.padSm)
                    .background(RTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
                }

                // Session history sparkline
                if avg > 0 {
                    let history = TestStore().history(for: mode)
                    if history.count >= 2 {
                        SurfaceCard {
                            VStack(spacing: 10) {
                                HStack {
                                    Text("PROGRESS (\(history.count) SESSIONS)")
                                        .font(RTheme.mono(9, weight: .medium))
                                        .foregroundStyle(RTheme.muted)
                                        .tracking(3)
                                    Spacer()
                                    let trend = history.last! - history.first!
                                    HStack(spacing: 3) {
                                        Image(systemName: trend < 0 ? "arrow.down" : "arrow.up")
                                            .font(.system(size: 9, weight: .bold))
                                        Text(String(format: "%.0fms", abs(trend)))
                                            .font(RTheme.mono(9, weight: .bold))
                                    }
                                    .foregroundStyle(trend < 0 ? RTheme.green : RTheme.red)
                                }
                                SparklineView(values: history)
                                    .frame(height: 44)
                            }
                        }
                    }
                }

                // Trial breakdown with bar chart
                SurfaceCard {
                    VStack(spacing: 14) {
                        Text("TRIAL BREAKDOWN")
                            .font(RTheme.mono(9, weight: .medium))
                            .foregroundStyle(RTheme.muted)
                            .tracking(3)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Bar chart
                        if validResults.count > 0 {
                            TrialBarChart(results: results)
                        }

                        ForEach(Array(results.enumerated()), id: \.0) { i, ms in
                            HStack {
                                Text("T\(i+1)")
                                    .font(RTheme.mono(11))
                                    .foregroundStyle(RTheme.faint)
                                    .frame(width: 22, alignment: .leading)
                                Spacer()
                                if ms >= 999 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 11))
                                            .foregroundStyle(RTheme.red)
                                        Text("MISS")
                                            .font(RTheme.mono(12, weight: .bold))
                                            .foregroundStyle(RTheme.red)
                                    }
                                } else {
                                    Text(String(format: "%.0f ms", ms))
                                        .font(RTheme.mono(13, weight: .bold))
                                        .foregroundStyle(msColor(ms))
                                }
                            }
                        }
                    }
                }

                // Speed class breakdown
                if validResults.count > 0 {
                    SurfaceCard {
                        VStack(spacing: 10) {
                            Text("SPEED BREAKDOWN")
                                .font(RTheme.mono(9, weight: .medium))
                                .foregroundStyle(RTheme.muted)
                                .tracking(3)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            let buckets: [(String, ClosedRange<Double>, Color)] = [
                                ("ELITE", 0...199, RTheme.green),
                                ("FAST", 200...269, RTheme.gold),
                                ("AVERAGE", 270...349, RTheme.muted),
                                ("SLOW", 350...9999, RTheme.red),
                            ]
                            ForEach(buckets, id: \.0) { label, range, color in
                                let count = validResults.filter { range.contains($0) }.count
                                if count > 0 {
                                    HStack(spacing: 10) {
                                        Text(label)
                                            .font(RTheme.mono(9, weight: .bold))
                                            .foregroundStyle(color)
                                            .tracking(2)
                                            .frame(width: 60, alignment: .leading)
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .stroke(color.opacity(0.3), lineWidth: 1)
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(color.opacity(0.3))
                                                    .frame(width: geo.size.width * CGFloat(count) / CGFloat(validResults.count))
                                            }
                                        }
                                        .frame(height: 14)
                                        Text("\(count)")
                                            .font(RTheme.mono(11, weight: .bold))
                                            .foregroundStyle(color)
                                            .frame(width: 16)
                                    }
                                }
                            }
                        }
                    }
                }

                // Context
                if avg > 0 {
                    Text("At 60mph you travel \(String(format: "%.1f", feet)) feet before your foot hits the brake.")
                        .font(RTheme.mono(11))
                        .foregroundStyle(RTheme.muted)
                        .multilineTextAlignment(.center)
                }

                // Buttons
                VStack(spacing: 12) {
                    GoldButton(label: "PLAY AGAIN", action: onReplay, fullWidth: true)
                    Button(action: onHome) {
                        Text("HOME")
                            .font(RTheme.rounded(14, weight: .semibold))
                            .foregroundStyle(RTheme.muted)
                            .tracking(3)
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, RTheme.pad)
            .padding(.top, 12)
        }
    }

    private func statCell(_ label: String, _ value: String, color: Color = RTheme.white) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(RTheme.mono(8, weight: .medium))
                .foregroundStyle(RTheme.muted)
                .tracking(2)
            Text(value)
                .font(RTheme.mono(15, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func msColor(_ ms: Double) -> Color {
        switch ms {
        case ..<200: return RTheme.green
        case 200..<270: return RTheme.gold
        default: return RTheme.red
        }
    }
}

// MARK: - Pulsing wait indicator

struct PulsingWaitDot: View {
    @State private var scale1: CGFloat = 1.0
    @State private var scale2: CGFloat = 1.0
    @State private var scale3: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 12) {
            dot.scaleEffect(scale1)
            dot.scaleEffect(scale2)
            dot.scaleEffect(scale3)
        }
        .onAppear { animate() }
    }

    private var dot: some View {
        Circle()
            .fill(RTheme.gold.opacity(0.6))
            .frame(width: 10, height: 10)
    }

    private func animate() {
        let dur: Double = 0.5
        withAnimation(.easeInOut(duration: dur).repeatForever().delay(0)) {
            scale1 = 1.6
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) {
            withAnimation(.easeInOut(duration: dur).repeatForever()) {
                scale2 = 1.6
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            withAnimation(.easeInOut(duration: dur).repeatForever()) {
                scale3 = 1.6
            }
        }
    }
}

// MARK: - Trial bar chart

struct TrialBarChart: View {
    let results: [Double]

    private var validResults: [Double] { results.filter { $0 < 999 } }
    private var maxVal: Double { validResults.max() ?? 500 }
    private var minVal: Double { validResults.min() ?? 100 }

    @State private var animated = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(results.enumerated()), id: \.0) { i, ms in
                let isError = ms >= 999
                let pct: Double = isError ? 0.1 : (maxVal > minVal ? (ms - minVal) / (maxVal - minVal) * 0.7 + 0.15 : 0.5)
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isError ? RTheme.red.opacity(0.6) : barColor(ms))
                        .frame(height: animated ? CGFloat(pct) * 70 : 4)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(i) * 0.07), value: animated)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 74)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { animated = true }
        }
    }

    private func barColor(_ ms: Double) -> Color {
        switch ms {
        case ..<200: return RTheme.green
        case 200..<270: return RTheme.gold
        default: return RTheme.red.opacity(0.8)
        }
    }
}

// MARK: - Sparkline view (session history)

struct SparklineView: View {
    let values: [Double]

    @State private var drawn = false

    private var minVal: Double { values.min() ?? 0 }
    private var maxVal: Double { values.max() ?? 1 }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pts = chartPoints(width: w, height: h)

            ZStack {
                // Area fill
                if pts.count > 1 {
                    Path { path in
                        path.move(to: CGPoint(x: pts[0].x, y: h))
                        for p in pts { path.addLine(to: p) }
                        path.addLine(to: CGPoint(x: pts.last!.x, y: h))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(
                        colors: [RTheme.gold.opacity(0.25), RTheme.gold.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                }

                // Line
                if pts.count > 1 {
                    Path { path in
                        path.move(to: pts[0])
                        for p in pts.dropFirst() { path.addLine(to: p) }
                    }
                    .trim(from: 0, to: drawn ? 1 : 0)
                    .stroke(RTheme.gold, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .animation(.easeOut(duration: 0.8), value: drawn)
                }

                // Last dot
                if let last = pts.last {
                    Circle()
                        .fill(RTheme.gold)
                        .shadow(color: RTheme.gold.opacity(0.8), radius: 6)
                        .frame(width: 8, height: 8)
                        .position(last)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { drawn = true }
        }
    }

    private func chartPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let range = maxVal - minVal
        let step = width / CGFloat(values.count - 1)
        return values.enumerated().map { i, v in
            let x = CGFloat(i) * step
            // Invert: lower ms = higher on chart (better = higher)
            let norm = range > 0 ? (v - minVal) / range : 0.5
            let y = height - CGFloat(norm) * height * 0.85 - height * 0.075
            return CGPoint(x: x, y: y)
        }
    }
}
