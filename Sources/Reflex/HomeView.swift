import SwiftUI

struct HomeView: View {
    let onSelect: (TestMode) -> Void

    private let store = TestStore()
    @State private var bestMS: Double? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("REFLEX")
                        .font(RTheme.serif(48, weight: .black))
                        .foregroundStyle(RTheme.gold)
                        .tracking(10)

                    Text("measure your reaction time")
                        .font(RTheme.mono(13))
                        .foregroundStyle(RTheme.muted)
                        .tracking(2)
                }
                .padding(.top, 64)
                .padding(.bottom, 40)

                // Personal best card
                if let ms = bestMS {
                    SurfaceCard {
                        VStack(spacing: 6) {
                            Text("YOUR BEST")
                                .font(RTheme.mono(11, weight: .medium))
                                .foregroundStyle(RTheme.muted)
                                .tracking(3)

                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text(String(format: "%.0f", ms))
                                    .font(RTheme.mono(64, weight: .bold))
                                    .foregroundStyle(RTheme.gold)
                                Text("ms")
                                    .font(RTheme.mono(20))
                                    .foregroundStyle(RTheme.muted)
                            }

                            Text(ReactionBenchmarks.label(ms: ms).uppercased())
                                .font(RTheme.mono(11, weight: .medium))
                                .foregroundStyle(speedColor(ms: ms))
                                .tracking(3)

                            Divider()
                                .overlay(RTheme.faint)
                                .padding(.vertical, 8)

                            HStack(spacing: 24) {
                                statPill(
                                    label: "PERCENTILE",
                                    value: "TOP \(100 - ReactionBenchmarks.percentile(ms: ms))%"
                                )
                                statPill(
                                    label: "60MPH",
                                    value: String(format: "%.1f ft", ReactionBenchmarks.drivingFeet(ms: ms))
                                )
                            }
                        }
                    }
                    .padding(.horizontal, RTheme.pad)
                    .padding(.bottom, 32)
                } else {
                    // First time: teaser card
                    SurfaceCard {
                        VStack(spacing: 10) {
                            Text("?")
                                .font(RTheme.mono(64, weight: .bold))
                                .foregroundStyle(RTheme.goldDim)
                            Text("Complete a test to see your baseline")
                                .font(RTheme.mono(13))
                                .foregroundStyle(RTheme.muted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, RTheme.pad)
                    .padding(.bottom, 32)
                }

                // Test mode cards
                VStack(spacing: 12) {
                    ForEach(TestMode.allCases) { mode in
                        TestModeCard(
                            mode: mode,
                            best: store.bestMS(for: mode),
                            onTap: { onSelect(mode) }
                        )
                    }
                }
                .padding(.horizontal, RTheme.pad)

                // Bottom context
                VStack(spacing: 6) {
                    Text("Average human: 200–250ms")
                        .font(RTheme.mono(11))
                        .foregroundStyle(RTheme.faint)
                    Text("F1 drivers: ~150ms  |  Impaired: 300ms+")
                        .font(RTheme.mono(11))
                        .foregroundStyle(RTheme.faint)
                }
                .padding(.top, 36)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            // Show best across all modes
            let bests = TestMode.allCases.compactMap { store.bestMS(for: $0) }
            bestMS = bests.min()
        }
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(RTheme.mono(9, weight: .medium))
                .foregroundStyle(RTheme.muted)
                .tracking(2)
            Text(value)
                .font(RTheme.mono(15, weight: .bold))
                .foregroundStyle(RTheme.white)
        }
    }

    private func speedColor(ms: Double) -> Color {
        switch ms {
        case ..<200: return RTheme.green
        case 200..<270: return RTheme.gold
        default: return RTheme.red
        }
    }
}

// MARK: - TestModeCard

private struct TestModeCard: View {
    let mode: TestMode
    let best: Double?
    let onTap: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(RTheme.goldDim)
                        .frame(width: 48, height: 48)
                    Text(modeIcon)
                        .font(.system(size: 22))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(RTheme.rounded(17, weight: .bold))
                        .foregroundStyle(RTheme.white)
                        .tracking(2)
                    Text(mode.subtitle)
                        .font(RTheme.mono(12))
                        .foregroundStyle(RTheme.muted)
                }

                Spacer()

                if let ms = best {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.0f", ms))
                            .font(RTheme.mono(20, weight: .bold))
                            .foregroundStyle(RTheme.gold)
                        Text("ms")
                            .font(RTheme.mono(10))
                            .foregroundStyle(RTheme.muted)
                    }
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(RTheme.muted)
                }
            }
            .padding(RTheme.pad)
            .background(RTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: RTheme.radius))
            .scaleEffect(pressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in withAnimation(.easeInOut(duration: 0.08)) { pressed = true } }
            .onEnded   { _ in withAnimation(.easeInOut(duration: 0.15)) { pressed = false } }
        )
    }

    private var modeIcon: String {
        switch mode {
        case .simpleTap: return "⚡️"
        case .choice:    return "⬅️"
        case .suppress:  return "🚫"
        }
    }
}
