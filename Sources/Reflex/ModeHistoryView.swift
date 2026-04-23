import SwiftUI

// MARK: - Mode History View
// Sheet showing full session history for a specific test mode.

struct ModeHistoryView: View {
    let mode: TestMode
    let onDismiss: () -> Void

    private let store = TestStore()

    var body: some View {
        ZStack {
            RTheme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(mode.emoji + " " + mode.title)
                            .font(RTheme.rounded(20, weight: .bold))
                            .foregroundStyle(RTheme.white)
                        Text(mode.subtitle)
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

                let history = store.history(for: mode)
                let best = store.bestMS(for: mode)

                if history.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 48))
                            .foregroundStyle(RTheme.faint)
                        Text("No sessions yet")
                            .font(RTheme.mono(16, weight: .medium))
                            .foregroundStyle(RTheme.muted)
                        Text("Complete a session to see your history here")
                            .font(RTheme.mono(11))
                            .foregroundStyle(RTheme.faint)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {

                            // Summary stats
                            HStack(spacing: 0) {
                                histStatCell("SESSIONS", "\(history.count)")
                                Divider().overlay(RTheme.faint).frame(height: 36)
                                if let b = best {
                                    histStatCell("BEST", String(format: "%.0fms", b))
                                }
                                Divider().overlay(RTheme.faint).frame(height: 36)
                                let avg = history.reduce(0, +) / Double(history.count)
                                histStatCell("AVG", String(format: "%.0fms", avg))
                            }
                            .padding(RTheme.padSm)
                            .background(RTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))

                            // Sparkline
                            if history.count >= 2 {
                                VStack(spacing: 10) {
                                    HStack {
                                        Text("TREND")
                                            .font(RTheme.mono(9, weight: .medium))
                                            .foregroundStyle(RTheme.muted)
                                            .tracking(3)
                                        Spacer()
                                        let trend = history.last! - history.first!
                                        HStack(spacing: 4) {
                                            Image(systemName: trend < 0 ? "arrow.down" : "arrow.up")
                                                .font(.system(size: 9, weight: .bold))
                                            Text(String(format: "%.0fms overall", abs(trend)))
                                                .font(RTheme.mono(9, weight: .bold))
                                        }
                                        .foregroundStyle(trend < 0 ? RTheme.green : RTheme.red)
                                    }
                                    SparklineView(values: history)
                                        .frame(height: 60)

                                    // Min / Max labels
                                    HStack {
                                        let minVal = history.min()!
                                        let maxVal = history.max()!
                                        Text("BEST: \(String(format: "%.0fms", minVal))")
                                            .font(RTheme.mono(9))
                                            .foregroundStyle(RTheme.green)
                                        Spacer()
                                        Text("WORST: \(String(format: "%.0fms", maxVal))")
                                            .font(RTheme.mono(9))
                                            .foregroundStyle(RTheme.red)
                                    }
                                }
                                .padding(RTheme.padSm)
                                .background(RTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
                            }

                            // Session list (reverse chronological)
                            VStack(alignment: .leading, spacing: 0) {
                                Text("SESSION LOG")
                                    .font(RTheme.mono(9, weight: .bold))
                                    .foregroundStyle(RTheme.faint)
                                    .tracking(3)
                                    .padding(.bottom, 10)
                                    .padding(.horizontal, 4)

                                VStack(spacing: 0) {
                                    ForEach(Array(history.enumerated().reversed()), id: \.0) { i, ms in
                                        HStack {
                                            Text("#\(i + 1)")
                                                .font(RTheme.mono(11))
                                                .foregroundStyle(RTheme.faint)
                                                .frame(width: 28, alignment: .leading)

                                            // Mini bar
                                            GeometryReader { geo in
                                                ZStack(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .fill(RTheme.faint.opacity(0.3))
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .fill(msBarColor(ms))
                                                        .frame(width: geo.size.width * barWidth(ms, history: history))
                                                }
                                            }
                                            .frame(height: 10)

                                            Text(String(format: "%.0fms", ms))
                                                .font(RTheme.mono(13, weight: .bold))
                                                .foregroundStyle(msColor(ms))
                                                .frame(width: 60, alignment: .trailing)

                                            if ms == history.min() {
                                                Image(systemName: "crown.fill")
                                                    .font(.system(size: 9))
                                                    .foregroundStyle(RTheme.gold)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, RTheme.padSm)

                                        if i > 0 {
                                            Divider().overlay(RTheme.faint).padding(.leading, 36)
                                        }
                                    }
                                }
                                .background(RTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
                            }
                        }
                        .padding(.horizontal, RTheme.pad)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }

    private func histStatCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(RTheme.mono(18, weight: .bold))
                .foregroundStyle(RTheme.white)
            Text(label)
                .font(RTheme.mono(8))
                .foregroundStyle(RTheme.faint)
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
    }

    private func barWidth(_ ms: Double, history: [Double]) -> CGFloat {
        let maxMs = history.max() ?? 1
        let minMs = history.min() ?? 0
        guard maxMs > minMs else { return 0.5 }
        return CGFloat((maxMs - ms) / (maxMs - minMs)) * 0.85 + 0.15
    }

    private func msBarColor(_ ms: Double) -> Color {
        switch ms {
        case ..<200: return RTheme.green
        case 200..<270: return RTheme.gold
        default: return RTheme.red
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
