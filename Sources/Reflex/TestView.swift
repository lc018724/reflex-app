import SwiftUI
import UIKit

struct TestView: View {
    private let impactLight  = UIImpactFeedbackGenerator(style: .light)
    private let impactHeavy  = UIImpactFeedbackGenerator(style: .heavy)
    private let notif        = UINotificationFeedbackGenerator()
    @ObservedObject var engine: TestEngine
    let mode: TestMode
    let onDismiss: () -> Void

    private let store = TestStore()
    @State private var suppressTimer: Task<Void, Never>? = nil
    @State private var bgFlash: Color = RTheme.bg

    var body: some View {
        ZStack {
            // Full-screen background — flashes gold on stimulus
            bgFlash.ignoresSafeArea()
                .animation(.easeOut(duration: 0.08), value: bgFlash)

            VStack {
                // Top bar
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(RTheme.muted)
                            .padding(10)
                            .background(RTheme.surface)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text(mode.title)
                        .font(RTheme.mono(13, weight: .medium))
                        .foregroundStyle(RTheme.muted)
                        .tracking(3)
                    Spacer()
                    // Balance
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, RTheme.pad)
                .padding(.top, 56)

                Spacer()

                // Main phase display
                phaseContent
                    .animation(.easeInOut(duration: 0.15), value: phaseKey)

                Spacer()
                Spacer()
            }
        }
        .onChange(of: engine.phaseID) { _ in
            handlePhaseChange(engine.phase)
        }
        // Full-screen tap target for simple tap and suppress
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                handleScreenTap(side: nil)
            }
        )
        .onDisappear {
            suppressTimer?.cancel()
        }
    }

    // MARK: - Phase content

    @ViewBuilder
    private var phaseContent: some View {
        switch engine.phase {
        case .idle:
            phaseLabel("GET READY", color: RTheme.muted)

        case .countdown(let n):
            phaseLabel(n == 0 ? "..." : "\(n)", color: n == 0 ? RTheme.muted : RTheme.white)

        case .waiting:
            phaseLabel("...", color: RTheme.muted)

        case .stimulus(let stim):
            stimulusView(stim)

        case .tooSoon:
            VStack(spacing: 16) {
                phaseLabel("TOO SOON", color: RTheme.red)
                Text("Wait for the flash")
                    .font(RTheme.mono(14))
                    .foregroundStyle(RTheme.muted)
            }

        case .result(let ms, let trial, let total):
            resultMoment(ms: ms, trial: trial, total: total)

        case .sessionDone(let avg, let best, let results):
            SessionSummaryView(
                mode: mode,
                avg: avg,
                best: best,
                results: results,
                onReplay: {
                    engine.startSession(mode: mode)
                },
                onHome: onDismiss
            )
        }
    }

    @ViewBuilder
    private func stimulusView(_ stim: Stimulus) -> some View {
        switch mode {
        case .simpleTap:
            Circle()
                .fill(RTheme.gold)
                .frame(width: 160, height: 160)
                .shadow(color: RTheme.gold.opacity(0.7), radius: 40)
                .transition(.scale(scale: 0.5).combined(with: .opacity))

        case .choice:
            ChoiceStimulusView(stim: stim) { side in
                engine.handleTap(side: side)
            }

        case .suppress:
            SuppressStimulusView(stim: stim)
        }
    }

    // MARK: - Helpers

    private func phaseLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(RTheme.mono(80, weight: .bold))
            .foregroundStyle(color)
            .contentTransition(.numericText())
    }

    private var phaseKey: String {
        switch engine.phase {
        case .idle:            return "idle"
        case .countdown(let n): return "cd\(n)"
        case .waiting:         return "wait"
        case .stimulus:        return "stim"
        case .tooSoon:         return "soon"
        case .result(_, let t, _): return "res\(t)"
        case .sessionDone:     return "done"
        }
    }

    private func handleScreenTap(side: Stimulus.Side?) {
        switch engine.phase {
        case .waiting:
            engine.handleTap(side: side)
        case .stimulus(let stim):
            // For simpleTap/suppress, handle here; choice handled in sub-view buttons
            if mode == .simpleTap || mode == .suppress {
                engine.handleTap(side: nil)
            }
            _ = stim
        default:
            break
        }
    }

    private func handlePhaseChange(_ phase: TestPhase) {
        switch phase {
        case .stimulus(let stim):
            impactLight.impactOccurred()
            // Flash background gold for simpleTap
            if mode == .simpleTap {
                bgFlash = RTheme.gold
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    bgFlash = RTheme.bg
                }
            }
            // Start no-tap timer for suppress no-go trials
            if mode == .suppress, case .noGo = stim {
                suppressTimer?.cancel()
                suppressTimer = Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    guard !Task.isCancelled else { return }
                    engine.handleNoTap()
                }
            }
            // Auto-advance suppress go trials if not tapped within 1.5s
            if mode == .suppress, case .go = stim {
                suppressTimer?.cancel()
                suppressTimer = Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    guard !Task.isCancelled else { return }
                    engine.handleNoTap()
                }
            }

        case .result(let ms, _, _):
            suppressTimer?.cancel()
            bgFlash = RTheme.bg
            if ms < 0 { notif.notificationOccurred(.error) }
            else { impactHeavy.impactOccurred() }

        case .sessionDone(let avg, _, _):
            suppressTimer?.cancel()
            store.appendSession(avg: avg, for: mode)
            store.totalSessions += 1
            if avg > 0 { store.updateBest(ms: avg, for: mode) }

        default:
            break
        }
    }
}

// MARK: - Result moment (between trials)

private func resultMoment(ms: Double, trial: Int, total: Int) -> some View {
    VStack(spacing: 20) {
        if ms < 0 {
            Text("MISS")
                .font(RTheme.mono(64, weight: .bold))
                .foregroundStyle(RTheme.red)
        } else {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(String(format: "%.0f", ms))
                    .font(RTheme.mono(80, weight: .bold))
                    .foregroundStyle(msColor(ms))
                    .contentTransition(.numericText())
                Text("ms")
                    .font(RTheme.mono(24))
                    .foregroundStyle(RTheme.muted)
            }
        }

        // Trial progress dots
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i < trial ? RTheme.gold : RTheme.faint)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

private func msColor(_ ms: Double) -> Color {
    switch ms {
    case ..<200: return RTheme.green
    case 200..<270: return RTheme.gold
    default: return RTheme.red
    }
}

// MARK: - Choice stimulus

private struct ChoiceStimulusView: View {
    let stim: Stimulus
    let onTap: (Stimulus.Side) -> Void

    var body: some View {
        VStack(spacing: 40) {
            Text("TAP THE CORRECT SIDE")
                .font(RTheme.mono(11, weight: .medium))
                .foregroundStyle(RTheme.muted)
                .tracking(3)

            HStack(spacing: 32) {
                sideButton(side: .left)
                sideButton(side: .right)
            }
        }
    }

    private func sideButton(side: Stimulus.Side) -> some View {
        let isTarget: Bool
        if case .go(let s) = stim { isTarget = s == side } else { isTarget = false }

        return Button { onTap(side) } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(isTarget ? RTheme.gold : RTheme.surface)
                    .frame(width: 130, height: 130)
                    .shadow(color: isTarget ? RTheme.gold.opacity(0.5) : .clear, radius: 20)
                Image(systemName: side == .left ? "arrow.left" : "arrow.right")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(isTarget ? RTheme.bg : RTheme.muted)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Suppress stimulus

private struct SuppressStimulusView: View {
    let stim: Stimulus

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(isNoGo ? RTheme.red.opacity(0.15) : RTheme.gold.opacity(0.15))
                    .frame(width: 180, height: 180)
                    .shadow(color: (isNoGo ? RTheme.red : RTheme.gold).opacity(0.4), radius: 30)

                if isNoGo {
                    Image(systemName: "xmark")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundStyle(RTheme.red)
                } else {
                    Circle()
                        .fill(RTheme.gold)
                        .frame(width: 100, height: 100)
                }
            }
            .transition(.scale(scale: 0.5).combined(with: .opacity))

            Text(isNoGo ? "DON'T TAP" : "TAP NOW")
                .font(RTheme.mono(14, weight: .bold))
                .foregroundStyle(isNoGo ? RTheme.red : RTheme.gold)
                .tracking(4)
        }
    }

    private var isNoGo: Bool {
        if case .noGo = stim { return true }
        return false
    }
}

// MARK: - Session summary

struct SessionSummaryView: View {
    let mode: TestMode
    let avg: Double
    let best: Double
    let results: [Double]
    let onReplay: () -> Void
    let onHome: () -> Void

    private var validResults: [Double] { results.filter { $0 < 999 } }
    private var percentile: Int { ReactionBenchmarks.percentile(ms: avg) }
    private var feet: Double { ReactionBenchmarks.drivingFeet(ms: avg) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {

                // Big score
                VStack(spacing: 10) {
                    Text("YOUR AVERAGE")
                        .font(RTheme.mono(11, weight: .medium))
                        .foregroundStyle(RTheme.muted)
                        .tracking(3)

                    if avg > 0 {
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
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
                        Text("You tapped too early every round")
                            .font(RTheme.mono(13))
                            .foregroundStyle(RTheme.muted)
                    }
                }

                // Stats row
                if avg > 0 {
                    HStack(spacing: 0) {
                        statCell(label: "PERCENTILE", value: "TOP \(100 - percentile)%")
                        Divider().overlay(RTheme.faint).frame(height: 44)
                        statCell(label: "BEST TRIAL", value: String(format: "%.0fms", best))
                        Divider().overlay(RTheme.faint).frame(height: 44)
                        statCell(label: "60MPH", value: String(format: "%.1f ft", feet))
                    }
                    .padding(RTheme.pad)
                    .background(RTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: RTheme.radius))
                }

                // Trial breakdown
                if !validResults.isEmpty {
                    SurfaceCard {
                        VStack(spacing: 12) {
                            Text("TRIAL BREAKDOWN")
                                .font(RTheme.mono(10, weight: .medium))
                                .foregroundStyle(RTheme.muted)
                                .tracking(3)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(Array(results.enumerated()), id: \.0) { i, ms in
                                HStack {
                                    Text("Trial \(i + 1)")
                                        .font(RTheme.mono(13))
                                        .foregroundStyle(RTheme.muted)
                                    Spacer()
                                    if ms >= 999 {
                                        Text("MISS")
                                            .font(RTheme.mono(13, weight: .bold))
                                            .foregroundStyle(RTheme.red)
                                    } else {
                                        Text(String(format: "%.0f ms", ms))
                                            .font(RTheme.mono(13, weight: .bold))
                                            .foregroundStyle(msColor(ms))
                                    }
                                }
                            }
                        }
                    }
                }

                // Context
                if avg > 0 {
                    Text("At 60mph you travel \(String(format: "%.1f", feet)) feet before your foot hits the brake.")
                        .font(RTheme.mono(12))
                        .foregroundStyle(RTheme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                // Buttons
                VStack(spacing: 12) {
                    GoldButton(label: "PLAY AGAIN", action: onReplay, fullWidth: true)
                    Button(action: onHome) {
                        Text("HOME")
                            .font(RTheme.rounded(15, weight: .semibold))
                            .foregroundStyle(RTheme.muted)
                            .tracking(3)
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, RTheme.pad)
            .padding(.top, 20)
        }
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(RTheme.mono(9, weight: .medium))
                .foregroundStyle(RTheme.muted)
                .tracking(2)
            Text(value)
                .font(RTheme.mono(16, weight: .bold))
                .foregroundStyle(RTheme.white)
        }
        .frame(maxWidth: .infinity)
    }
}
