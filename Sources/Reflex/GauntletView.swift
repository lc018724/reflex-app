import SwiftUI
import UIKit

// MARK: - Gauntlet Mode
// 10 random cognitive tests, 1 trial each, scored on composite reaction speed.
// Tests are drawn from all 5 tiers (2 per tier) for balanced coverage.

// MARK: - Entry card shown on HomeView

struct GauntletEntryCard: View {
    let onStart: () -> Void
    @State private var pulse = false
    private let store = TestStore()

    var body: some View {
        Button(action: onStart) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(RTheme.red.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Circle()
                        .stroke(RTheme.red.opacity(pulse ? 0.5 : 0.1), lineWidth: 2)
                        .frame(width: 52, height: 52)
                        .scaleEffect(pulse ? 1.35 : 1.0)
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(RTheme.red)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("GAUNTLET")
                            .font(RTheme.mono(9, weight: .bold))
                            .foregroundStyle(RTheme.red.opacity(0.9))
                            .tracking(2)
                        Text("RAPID FIRE")
                            .font(RTheme.mono(8, weight: .bold))
                            .foregroundStyle(RTheme.bg)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(RTheme.red)
                            .clipShape(Capsule())
                    }
                    Text("10 TESTS · 1 SHOT EACH")
                        .font(RTheme.rounded(17, weight: .bold))
                        .foregroundStyle(RTheme.white)
                    if let best = store.gauntletBestAvg {
                        HStack(spacing: 8) {
                            Text("BEST \(String(format: "%.0f", best))ms · \(ReactionBenchmarks.label(ms: best).uppercased())")
                                .font(RTheme.mono(9))
                                .foregroundStyle(speedColor(best))
                            let hist = store.gauntletHistory
                            if hist.count >= 3 {
                                SparklineView(values: hist)
                                    .frame(width: 50, height: 16)
                                    .opacity(0.8)
                            }
                        }
                    } else {
                        Text("All tiers · composite score")
                            .font(RTheme.mono(10))
                            .foregroundStyle(RTheme.muted)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RTheme.red.opacity(0.7))
            }
            .padding(RTheme.padSm)
            .background(
                LinearGradient(
                    colors: [RTheme.surface, RTheme.red.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: RTheme.radius))
            .overlay(
                RoundedRectangle(cornerRadius: RTheme.radius)
                    .stroke(RTheme.red.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("gauntlet-card")
        .accessibilityLabel("GAUNTLET")
        .onAppear { pulse = true }
    }

    private func speedColor(_ ms: Double) -> Color {
        switch ms {
        case ..<200: return RTheme.green
        case 200..<270: return RTheme.gold
        default: return RTheme.red
        }
    }
}

// MARK: - Gauntlet phase

enum GauntletState {
    case modeIntro    // show "Next up: MODE" card 1.5s
    case testing      // running the trial
    case resultFlash  // show result 0.9s
    case done         // final summary
}

// MARK: - Main view

struct GauntletView: View {
    let onDismiss: () -> Void

    @StateObject private var engine = TestEngine()
    @State private var gauntletModes: [TestMode] = []
    @State private var currentIndex: Int = 0
    @State private var results: [(mode: TestMode, ms: Double?, isError: Bool)] = []
    @State private var gauntletState: GauntletState = .modeIntro
    @State private var lastResult: (ms: Double, isError: Bool) = (0, false)
    @State private var bgFlash: Color = RTheme.bg
    @State private var suppressTimer: Task<Void, Never>? = nil
    @State private var introTask: Task<Void, Never>? = nil
    @State private var isNewBest: Bool = false

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let notif = UINotificationFeedbackGenerator()

    var body: some View {
        ZStack {
            bgFlash.ignoresSafeArea()
                .animation(.easeOut(duration: 0.07), value: bgFlash)

            switch gauntletState {
            case .modeIntro:
                modeIntroView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))

            case .testing:
                testingView
                    .transition(.opacity)

            case .resultFlash:
                resultFlashView
                    .transition(.opacity)

            case .done:
                summaryView
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: gauntletState == .modeIntro)
        .animation(.easeInOut(duration: 0.2), value: gauntletState == .done)
        .contentShape(Rectangle())
        .simultaneousGesture(tapGesture)
        .onChange(of: engine.phaseID) {
            handleEnginePhase(engine.phase)
        }
        .onAppear {
            gauntletModes = buildGauntletModes()
            results = gauntletModes.map { (mode: $0, ms: nil, isError: false) }
            startModeIntro()
        }
        .onDisappear {
            engine.reset()
            introTask?.cancel()
            suppressTimer?.cancel()
        }
    }

    // MARK: - Mode intro

    private var modeIntroView: some View {
        VStack(spacing: 0) {
            gauntletTopBar
            Spacer()
            if currentIndex < gauntletModes.count {
                let mode = gauntletModes[currentIndex]
                VStack(spacing: 20) {
                    // Progress indicators
                    HStack(spacing: 6) {
                        ForEach(0..<gauntletModes.count, id: \.self) { i in
                            Capsule()
                                .fill(dotColor(at: i))
                                .frame(width: i == currentIndex ? 22 : 8, height: 6)
                                .animation(.spring(response: 0.3), value: currentIndex)
                        }
                    }
                    .padding(.bottom, 8)

                    Text(mode.emoji)
                        .font(.system(size: 64))

                    VStack(spacing: 8) {
                        Text(mode.title)
                            .font(RTheme.rounded(36, weight: .black))
                            .foregroundStyle(RTheme.white)
                            .tracking(3)
                        Text(mode.subtitle)
                            .font(RTheme.mono(13))
                            .foregroundStyle(RTheme.muted)
                    }

                    HStack(spacing: 6) {
                        Text("\(currentIndex + 1)")
                            .font(RTheme.mono(13, weight: .bold))
                            .foregroundStyle(RTheme.gold)
                        Text("of 10")
                            .font(RTheme.mono(13))
                            .foregroundStyle(RTheme.faint)
                    }
                }
            }
            Spacer()
            Spacer()
        }
    }

    private func dotColor(at i: Int) -> Color {
        if i < currentIndex {
            return results[i].isError ? RTheme.red : RTheme.green
        } else if i == currentIndex {
            return RTheme.gold
        } else {
            return RTheme.faint
        }
    }

    // MARK: - Testing view

    private var testingView: some View {
        VStack(spacing: 0) {
            gauntletTopBar
            Spacer()

            Group {
                switch engine.phase {
                case .idle:
                    Color.clear

                case .instruction:
                    // Auto-dismissed; show brief mode name
                    if currentIndex < gauntletModes.count {
                        Text(gauntletModes[currentIndex].emoji)
                            .font(.system(size: 56))
                    }

                case .countdown(let n):
                    countdownView(n)

                case .waiting:
                    VStack(spacing: 24) {
                        if currentIndex < gauntletModes.count && gauntletModes[currentIndex] == .peripheral {
                            Text("WATCH THE EDGES")
                                .font(RTheme.mono(13, weight: .medium))
                                .foregroundStyle(RTheme.muted)
                                .tracking(4)
                        }
                        PulsingWaitDot()
                    }

                case .stimulus(let data):
                    StimulusRouter(data: data, mode: currentIndex < gauntletModes.count ? gauntletModes[currentIndex] : .flash, engine: engine)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))

                case .tooSoon:
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(RTheme.red)
                        Text("TOO SOON")
                            .font(RTheme.mono(44, weight: .bold))
                            .foregroundStyle(RTheme.red)
                            .tracking(4)
                    }

                case .result, .sessionDone:
                    Color.clear  // handled via phase listener

                case .sequenceInput(let steps, let inputSoFar, let target):
                    SequenceInputView(steps: steps, inputSoFar: inputSoFar,
                                      targetSteps: target, engine: engine)

                }
            }
            .animation(.easeInOut(duration: 0.15), value: engine.phaseID)

            Spacer()
            Spacer()
        }
        .contentShape(Rectangle())
    }

    // MARK: - Result flash view

    private var resultFlashView: some View {
        VStack(spacing: 0) {
            gauntletTopBar
            Spacer()

            VStack(spacing: 20) {
                if lastResult.isError {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(RTheme.red)
                    Text("ERROR")
                        .font(RTheme.mono(28, weight: .bold))
                        .foregroundStyle(RTheme.red)
                        .tracking(4)
                } else {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(String(format: "%.0f", lastResult.ms))
                            .font(RTheme.mono(72, weight: .bold))
                            .foregroundStyle(speedColor(lastResult.ms))
                        Text("ms")
                            .font(RTheme.mono(20))
                            .foregroundStyle(RTheme.muted)
                    }
                    Text(ReactionBenchmarks.label(ms: lastResult.ms).uppercased())
                        .font(RTheme.mono(13, weight: .bold))
                        .foregroundStyle(speedColor(lastResult.ms))
                        .tracking(3)
                }
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Summary view

    private var summaryView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(RTheme.gold)
                    Text("GAUNTLET DONE")
                        .font(RTheme.mono(20, weight: .bold))
                        .foregroundStyle(RTheme.white)
                        .tracking(4)
                    if let composite = compositeScore {
                        VStack(spacing: 4) {
                            HStack(alignment: .lastTextBaseline, spacing: 5) {
                                Text(String(format: "%.0f", composite))
                                    .font(RTheme.mono(52, weight: .bold))
                                    .foregroundStyle(speedColor(composite))
                                Text("ms avg")
                                    .font(RTheme.mono(16))
                                    .foregroundStyle(RTheme.muted)
                            }
                            Text(ReactionBenchmarks.label(ms: composite).uppercased())
                                .font(RTheme.mono(11, weight: .bold))
                                .foregroundStyle(speedColor(composite))
                                .tracking(3)
                            if isNewBest {
                                HStack(spacing: 5) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 10))
                                    Text("NEW PERSONAL BEST")
                                        .font(RTheme.mono(9, weight: .bold))
                                        .tracking(2)
                                }
                                .foregroundStyle(RTheme.bg)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(RTheme.gold)
                                .clipShape(Capsule())
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.top, 60)
                .padding(.bottom, 32)

                // Per-mode results
                VStack(spacing: 8) {
                    ForEach(Array(results.enumerated()), id: \.0) { i, result in
                        HStack(spacing: 12) {
                            Text(result.mode.emoji)
                                .font(.system(size: 20))
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.mode.title)
                                    .font(RTheme.rounded(14, weight: .bold))
                                    .foregroundStyle(RTheme.white)
                                Text(result.mode.subtitle)
                                    .font(RTheme.mono(9))
                                    .foregroundStyle(RTheme.faint)
                            }
                            Spacer()
                            if result.isError {
                                Text("ERR")
                                    .font(RTheme.mono(13, weight: .bold))
                                    .foregroundStyle(RTheme.red)
                            } else if let ms = result.ms {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "%.0fms", ms))
                                        .font(RTheme.mono(15, weight: .bold))
                                        .foregroundStyle(speedColor(ms))
                                    Text(ReactionBenchmarks.label(ms: ms).uppercased())
                                        .font(RTheme.mono(8))
                                        .foregroundStyle(RTheme.faint)
                                        .tracking(1)
                                }
                            } else {
                                Text("-")
                                    .font(RTheme.mono(13))
                                    .foregroundStyle(RTheme.faint)
                            }
                        }
                        .padding(.horizontal, RTheme.padSm)
                        .padding(.vertical, 10)
                        .background(RTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
                    }
                }
                .padding(.horizontal, RTheme.pad)

                VStack(spacing: 12) {
                    GoldButton(label: "RUN AGAIN", action: {
                        gauntletModes = buildGauntletModes()
                        results = gauntletModes.map { (mode: $0, ms: nil, isError: false) }
                        currentIndex = 0
                        isNewBest = false
                        engine.reset()
                        startModeIntro()
                    }, fullWidth: true)

                    Button("Back to Menu") { onDismiss() }
                        .font(RTheme.mono(14))
                        .foregroundStyle(RTheme.muted)
                }
                .padding(.horizontal, RTheme.pad)
                .padding(.top, 32)
                .padding(.bottom, 60)
            }
        }
    }

    private var compositeScore: Double? {
        let valid = results.compactMap { $0.isError ? nil : $0.ms }
        guard !valid.isEmpty else { return nil }
        return valid.reduce(0, +) / Double(valid.count)
    }

    // MARK: - Shared top bar

    private var gauntletTopBar: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: {
                    introTask?.cancel()
                    suppressTimer?.cancel()
                    engine.reset()
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RTheme.muted)
                        .frame(width: 36, height: 36)
                        .background(RTheme.surface)
                        .clipShape(Circle())
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(RTheme.red)
                    Text("GAUNTLET")
                        .font(RTheme.mono(13, weight: .medium))
                        .foregroundStyle(RTheme.muted)
                        .tracking(4)
                }
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }

            // Progress capsules
            if !gauntletModes.isEmpty {
                HStack(spacing: 5) {
                    ForEach(0..<gauntletModes.count, id: \.self) { i in
                        Capsule()
                            .fill(dotColor(at: i))
                            .frame(width: i == currentIndex ? 18 : 7, height: 5)
                            .animation(.spring(response: 0.3), value: currentIndex)
                    }
                }
            }
        }
        .padding(.horizontal, RTheme.pad)
        .padding(.top, 56)
    }

    // MARK: - Countdown view (copied from TestView pattern)

    private func countdownView(_ n: Int) -> some View {
        ZStack {
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
                .font(n == 0 ? RTheme.rounded(28, weight: .black) : RTheme.mono(72, weight: .bold))
                .foregroundStyle(n == 0 ? RTheme.gold : RTheme.white)
                .contentTransition(.numericText())
        }
    }

    // MARK: - Tap gesture

    private var tapGesture: some Gesture {
        TapGesture().onEnded {
            guard gauntletState == .testing else { return }
            let mode = currentIndex < gauntletModes.count ? gauntletModes[currentIndex] : .flash
            switch engine.phase {
            case .waiting:
                if [.flash, .antiTap, .goNoGo, .nBack, .peripheral].contains(mode) {
                    engine.handleTap()
                }
            case .stimulus:
                if [.flash, .antiTap, .peripheral].contains(mode) {
                    engine.handleTap()
                } else if mode == .doubleFlash {
                    engine.handleDoubleFlashTap()
                }
            default:
                break
            }
        }
    }

    // MARK: - Engine phase handler

    private func handleEnginePhase(_ phase: TestPhase) {
        switch phase {
        case .instruction:
            // Auto-dismiss the instruction screen in gauntlet mode
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                engine.dismissInstruction()
            }

        case .stimulus(let data):
            impactLight.impactOccurred()
            if case .flash = data {
                bgFlash = RTheme.gold
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { bgFlash = RTheme.bg }
            }
            if case .antiTap = data { bgFlash = RTheme.gold }
            switch data {
            case .goNoGo(let isGo) where !isGo:
                scheduleNoTap(delay: 1.5)
            case .nBack(_, let shouldTap) where !shouldTap:
                scheduleNoTap(delay: 1.5)
            default:
                break
            }

        case .result(let ms, _, _, let isError):
            // Capture result and advance to next mode
            lastResult = (ms, isError)
            if currentIndex < results.count {
                results[currentIndex] = (mode: gauntletModes[currentIndex], ms: ms, isError: isError)
            }

            if isError {
                notif.notificationOccurred(.error)
                bgFlash = RTheme.red.opacity(0.3)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) { bgFlash = RTheme.bg }
            } else {
                impactLight.impactOccurred()
                bgFlash = RTheme.green.opacity(0.2)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) { bgFlash = RTheme.bg }
            }

            withAnimation(.easeInOut(duration: 0.15)) {
                gauntletState = .resultFlash
            }

            engine.reset()
            suppressTimer?.cancel()

            // After brief result display, advance
            introTask = Task {
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard !Task.isCancelled else { return }
                advanceToNextMode()
            }

        case .sequenceInput:
            // Sequence modes need tap handling in the SequenceInputView itself
            break

        case .sessionDone:
            // Shouldn't happen in gauntlet since we reset after first result, but guard anyway
            break

        default:
            break
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

    // MARK: - Flow control

    private func startModeIntro() {
        introTask?.cancel()
        gauntletState = .modeIntro

        introTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                gauntletState = .testing
            }
            guard currentIndex < gauntletModes.count else { return }
            engine.startSession(mode: gauntletModes[currentIndex])

            // Safety timeout: if no result within 10 seconds, force error and advance
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled else { return }
            if gauntletState == .testing {
                if currentIndex < results.count {
                    results[currentIndex] = (mode: gauntletModes[currentIndex], ms: nil, isError: true)
                }
                engine.reset()
                suppressTimer?.cancel()
                advanceToNextMode()
            }
        }
    }

    private func advanceToNextMode() {
        currentIndex += 1
        if currentIndex >= gauntletModes.count {
            // Check and save best avg before transitioning to done state
            if let avg = compositeScore {
                let store = TestStore()
                isNewBest = store.gauntletBestAvg == nil || avg < store.gauntletBestAvg!
                store.updateGauntletBest(avg: avg)
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                gauntletState = .done
            }
        } else {
            startModeIntro()
        }
    }

    // MARK: - Mode selection

    private func buildGauntletModes() -> [TestMode] {
        // Pick 2 from each tier for balanced coverage
        let byTier: [[TestMode]] = [
            [.flash, .fallingBall, .antiTap, .doubleFlash],           // SPEED
            [.find, .colorTap, .oddOneOut, .peripheral],              // ATTENTION
            [.stroop, .reverseStroop, .mirror, .goNoGo],              // COGNITION
            [.math, .sequence, .nBack, .digitMatch],                  // MEMORY
            [.simon, .speedSort, .rhythm, .dualTrack],                // EXPERT
        ]
        var selected: [TestMode] = []
        for tier in byTier {
            selected += tier.shuffled().prefix(2)
        }
        return selected.shuffled()
    }

    // MARK: - Helpers

    private func speedColor(_ ms: Double) -> Color {
        switch ms {
        case ..<200: return RTheme.green
        case 200..<270: return RTheme.gold
        default: return RTheme.red
        }
    }
}
