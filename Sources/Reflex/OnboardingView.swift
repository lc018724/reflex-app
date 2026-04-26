import SwiftUI

// MARK: - First-launch onboarding
// Swipeable cards explaining what the app does, then a "Let's Go" CTA.

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0

    private let pages: [OnboardPage] = [
        OnboardPage(
            emoji: "⚡️",
            title: "Train Your Reflexes",
            body: "20 precision tests measuring your reaction speed, pattern recognition, and cognitive control.",
            accent: RTheme.accent
        ),
        OnboardPage(
            emoji: "🎯",
            title: "Every Mode Is Different",
            body: "From a simple flash tap to Stroop tests and rhythm prediction - each challenges your brain in a new way.",
            accent: RTheme.green
        ),
        OnboardPage(
            emoji: "📈",
            title: "Track Your Progress",
            body: "Session averages, personal bests, sparkline history, and a daily streak keep you coming back.",
            accent: Color(red: 0.55, green: 0.35, blue: 0.95)
        ),
        OnboardPage(
            emoji: "🕹️",
            title: "Arcade Mode",
            body: "DROP, WHACK, CHAIN, GRID, AVOID, and MEMORY - 6 score-chasing arcade games with speed ramps, lives, and combo multipliers.",
            accent: RTheme.red
        ),
        OnboardPage(
            emoji: "⚡️",
            title: "Gauntlet",
            body: "10-mode rapid-fire sprint across all difficulty tiers. One trial per mode, no warm-up - pure reflexes under pressure.",
            accent: RTheme.accent
        ),
    ]

    var body: some View {
        ZStack {
            RTheme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                // Page tabs
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { i, p in
                        pageCard(p)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 460)

                // Dot indicators
                HStack(spacing: 7) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? pages[page].accent : RTheme.faint)
                            .frame(width: i == page ? 22 : 7, height: 7)
                            .animation(.spring(response: 0.3), value: page)
                    }
                }
                .padding(.top, 24)

                Spacer()

                // CTA
                VStack(spacing: 12) {
                    PrimaryButton(label: page < pages.count - 1 ? "Next" : "Get Started") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            if page < pages.count - 1 {
                                page += 1
                            } else {
                                onFinish()
                            }
                        }
                    }

                    if page < pages.count - 1 {
                        Button("Skip") { onFinish() }
                            .font(RTheme.mono(13))
                            .foregroundStyle(RTheme.faint)
                    }
                }
                .padding(.horizontal, RTheme.pad)
                .padding(.bottom, 48)
            }
        }
    }

    private func pageCard(_ p: OnboardPage) -> some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(p.accent.opacity(0.12))
                    .frame(width: 130, height: 130)
                Circle()
                    .fill(p.accent.opacity(0.06))
                    .frame(width: 170, height: 170)
                Text(p.emoji)
                    .font(.system(size: 62))
            }

            VStack(spacing: 14) {
                Text(p.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(RTheme.white)
                    .multilineTextAlignment(.center)

                Text(p.body)
                    .font(.body)
                    .foregroundStyle(RTheme.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.horizontal, RTheme.pad)
    }
}

// MARK: - Page model

struct OnboardPage {
    let emoji: String
    let title: String
    let body: String
    let accent: Color
}
