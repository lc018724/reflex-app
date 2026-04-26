import SwiftUI

// MARK: - Settings sheet
// Accessible via gear icon on HomeView.

struct SettingsView: View {
    let onDismiss: () -> Void

    private let store = TestStore()
    @State private var showResetConfirm = false
    @State private var showOnboarding = false
    @State private var hapticsEnabled = UserDefaults.standard.bool(forKey: "hapticsEnabled") == false ? true : UserDefaults.standard.bool(forKey: "hapticsEnabled")
    @State private var soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") == nil ? true : UserDefaults.standard.bool(forKey: "soundEnabled")

    private var cognitiveModes: [TestMode] {
        TestMode.allCases.filter { !$0.isArcade }
    }

    private var bests: [Double] {
        cognitiveModes.compactMap { store.bestMS(for: $0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                statsSection
                preferencesSection
                actionsSection
                arcadeSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.automatic)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
            .alert("Reset all scores?", isPresented: $showResetConfirm) {
                Button("Reset", role: .destructive) {
                    RTheme.playSelectionHaptic()
                    store.resetAll()
                    onDismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This erases personal bests, session history, arcade scores, and your streak.")
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView {
                    showOnboarding = false
                }
            }
        }
    }

    private var statsSection: some View {
        Section("Your Stats") {
            LabeledContent("Completed", value: "\(bests.count) of \(cognitiveModes.count)")
            LabeledContent("Sessions", value: "\(store.totalSessions)")
            LabeledContent("Streak", value: "\(store.streak) days")
            if let best = bests.min() {
                LabeledContent("Best", value: String(format: "%.0f ms", best))
            }
            if let worst = bests.max() {
                LabeledContent("Slowest", value: String(format: "%.0f ms", worst))
            }
            if !bests.isEmpty {
                let avg = bests.reduce(0, +) / Double(bests.count)
                LabeledContent("Average", value: String(format: "%.0f ms", avg))
            }
        }
    }

    private var preferencesSection: some View {
        Section("Preferences") {
            Toggle(isOn: $hapticsEnabled) {
                Label("Haptic Feedback", systemImage: "hand.tap")
            }
            .tint(RTheme.accent)
            .onChange(of: hapticsEnabled) { _, value in
                UserDefaults.standard.set(value, forKey: "hapticsEnabled")
                if value { RTheme.playSelectionHaptic() }
            }

            Toggle(isOn: $soundEnabled) {
                Label("Sound Effects", systemImage: "speaker.wave.2")
            }
            .tint(RTheme.accent)
            .onChange(of: soundEnabled) { _, value in
                UserDefaults.standard.set(value, forKey: "soundEnabled")
            }
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button {
                RTheme.playSelectionHaptic()
                showOnboarding = true
            } label: {
                Label("View Tutorial", systemImage: "play.circle")
            }

            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label("Reset All Scores", systemImage: "trash")
            }
        }
    }

    private var arcadeSection: some View {
        Section("Arcade High Scores") {
            ForEach(arcadeModes, id: \.mode) { item in
                LabeledContent {
                    if let score = store.highScore(for: item.mode) {
                        Text("\(score) pts")
                    } else {
                        Text("Not played")
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    Label(item.mode.title.capitalized, systemImage: item.symbol)
                }
            }

            LabeledContent {
                if let best = store.gauntletBestAvg {
                    Text(String(format: "%.0f ms avg", best))
                } else {
                    Text("Not run")
                        .foregroundStyle(.secondary)
                }
            } label: {
                Label("Gauntlet", systemImage: "bolt.circle")
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0")
            LabeledContent("Modes", value: "20 cognitive + 6 arcade")
            LabeledContent("Data", value: "On device only")
        }
    }

    private var arcadeModes: [(mode: TestMode, symbol: String)] {
        [
            (.dropArcade, "circle.and.arrow.down"),
            (.whackArcade, "target"),
            (.chainArcade, "link"),
            (.gridArcade, "square.grid.3x3"),
            (.avoidArcade, "circle.dashed"),
            (.memoryArcade, "rectangle.grid.2x2")
        ]
    }
}
