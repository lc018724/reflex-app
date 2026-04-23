import SwiftUI

// MARK: - Settings sheet
// Accessible via gear icon on HomeView.

struct SettingsView: View {
    let onDismiss: () -> Void

    private let store = TestStore()
    @State private var showResetConfirm = false
    @State private var showOnboarding = false
    @State private var hapticsEnabled = UserDefaults.standard.bool(forKey: "hapticsEnabled") == false ? true : UserDefaults.standard.bool(forKey: "hapticsEnabled")
    @State private var didReset = false

    var body: some View {
        ZStack {
            RTheme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("SETTINGS")
                        .font(RTheme.mono(16, weight: .bold))
                        .foregroundStyle(RTheme.white)
                        .tracking(4)
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
                    VStack(spacing: 24) {

                        // Stats summary
                        settingsSection("YOUR STATS") {
                            statsGrid
                        }

                        // Preferences
                        settingsSection("PREFERENCES") {
                            Toggle(isOn: $hapticsEnabled) {
                                settingsRowLabel("Haptic Feedback", icon: "hand.tap.fill", color: RTheme.gold)
                            }
                            .tint(RTheme.gold)
                            .onChange(of: hapticsEnabled) { _, val in
                                UserDefaults.standard.set(val, forKey: "hapticsEnabled")
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, RTheme.padSm)
                        }

                        // Actions
                        settingsSection("ACTIONS") {
                            Button {
                                showOnboarding = true
                            } label: {
                                settingsRowLabel("View Tutorial", icon: "play.circle.fill", color: RTheme.green)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 6)
                            .padding(.horizontal, RTheme.padSm)

                            Divider().overlay(RTheme.faint)

                            Button {
                                showResetConfirm = true
                            } label: {
                                settingsRowLabel("Reset All Scores", icon: "trash.fill", color: RTheme.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 6)
                            .padding(.horizontal, RTheme.padSm)
                        }

                        // Arcade high scores
                        settingsSection("ARCADE HIGH SCORES") {
                            arcadeHighScores
                        }

                        // App info
                        settingsSection("ABOUT") {
                            settingsInfoRow("Version", "1.0")
                            Divider().overlay(RTheme.faint)
                            settingsInfoRow("Tests", "21 cognitive + 4 arcade")
                            Divider().overlay(RTheme.faint)
                            settingsInfoRow("Data stored", "On device only")
                        }
                    }
                    .padding(.horizontal, RTheme.pad)
                    .padding(.bottom, 60)
                }
            }

            // Reset confirmation
            if showResetConfirm {
                resetConfirmOverlay
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                showOnboarding = false
            }
        }
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        let nonArcade = TestMode.allCases.filter { !$0.isArcade }
        let bests = nonArcade.compactMap { store.bestMS(for: $0) }
        let totalSessions = store.totalSessions
        let streak = store.streak

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statsBubble("COMPLETED", "\(bests.count)/21", RTheme.gold)
            statsBubble("SESSIONS", "\(totalSessions)", RTheme.green)
            statsBubble("STREAK", "\(streak)🔥", RTheme.red)
            if let best = bests.min() {
                statsBubble("BEST", String(format: "%.0fms", best), RTheme.gold)
            }
            if let worst = bests.max() {
                statsBubble("WORST", String(format: "%.0fms", worst), RTheme.muted)
            }
            if bests.count > 0 {
                let avg = bests.reduce(0, +) / Double(bests.count)
                statsBubble("AVG", String(format: "%.0fms", avg), RTheme.white)
            }
        }
        .padding(RTheme.padSm)
    }

    private func statsBubble(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(RTheme.mono(16, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(RTheme.mono(7))
                .foregroundStyle(RTheme.faint)
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RTheme.bg)
        .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
    }

    // MARK: - Reset confirm overlay

    private var resetConfirmOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
                .onTapGesture { showResetConfirm = false }

            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(RTheme.red)
                Text("RESET ALL SCORES?")
                    .font(RTheme.mono(18, weight: .bold))
                    .foregroundStyle(RTheme.white)
                    .tracking(2)
                Text("This will erase all personal bests, session history, and your streak. It cannot be undone.")
                    .font(RTheme.mono(12))
                    .foregroundStyle(RTheme.muted)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button("Cancel") { showResetConfirm = false }
                        .font(RTheme.rounded(14, weight: .semibold))
                        .foregroundStyle(RTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))

                    Button("Reset") {
                        store.resetAll()
                        showResetConfirm = false
                        didReset = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            onDismiss()
                        }
                    }
                    .font(RTheme.rounded(14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RTheme.red)
                    .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
                }
            }
            .padding(RTheme.pad)
            .background(RTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: RTheme.radius))
            .padding(.horizontal, RTheme.pad)
        }
    }

    // MARK: - Helpers

    private var arcadeHighScores: some View {
        let arcadeModes: [(TestMode, String)] = [
            (.dropArcade, "dropArcade_highScore"),
            (.whackArcade, "whackArcade_highScore"),
            (.chainArcade, "chainArcade_highScore"),
            (.gridArcade, "gridArcade_highScore")
        ]
        return VStack(spacing: 0) {
            ForEach(Array(arcadeModes.enumerated()), id: \.0) { i, item in
                let (mode, key) = item
                let score = UserDefaults.standard.integer(forKey: key)
                HStack {
                    Text(mode.emoji)
                        .font(.system(size: 16))
                    Text(mode.title)
                        .font(RTheme.rounded(14, weight: .medium))
                        .foregroundStyle(RTheme.white)
                    Spacer()
                    if score > 0 {
                        Text("\(score) pts")
                            .font(RTheme.mono(13, weight: .bold))
                            .foregroundStyle(RTheme.gold)
                    } else {
                        Text("—")
                            .font(RTheme.mono(13))
                            .foregroundStyle(RTheme.faint)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, RTheme.padSm)
                if i < arcadeModes.count - 1 {
                    Divider().overlay(RTheme.faint)
                }
            }
        }
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(RTheme.mono(9, weight: .bold))
                .foregroundStyle(RTheme.faint)
                .tracking(3)
                .padding(.bottom, 8)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(RTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
        }
    }

    private func settingsRowLabel(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 24)
            Text(title)
                .font(RTheme.rounded(15, weight: .medium))
                .foregroundStyle(RTheme.white)
        }
    }

    private func settingsInfoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(RTheme.rounded(14))
                .foregroundStyle(RTheme.muted)
            Spacer()
            Text(value)
                .font(RTheme.mono(12))
                .foregroundStyle(RTheme.faint)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, RTheme.padSm)
    }
}
