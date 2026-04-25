import SwiftUI

struct ContentView: View {
    @StateObject private var engine = TestEngine()
    @State private var activeMode: TestMode? = Self.initialMode()
    @State private var showDirectGauntlet = Self.shouldShowDirectGauntlet()
    @State private var showOnboarding = Self.shouldShowOnboarding()
    @State private var didStartInitialMode = false

    private static func shouldShowOnboarding() -> Bool {
        if ProcessInfo.processInfo.arguments.contains("REFLEX_SKIP_ONBOARDING") {
            return false
        }
        return !UserDefaults.standard.bool(forKey: "didOnboard")
    }

    private static func shouldShowDirectGauntlet() -> Bool {
        ProcessInfo.processInfo.arguments.contains("REFLEX_START_GAUNTLET")
    }

    private static func initialMode() -> TestMode? {
        guard let rawValue = launchArgumentValue(after: "REFLEX_START_MODE") else {
            return nil
        }
        return TestMode(rawValue: rawValue)
    }

    private static func launchArgumentValue(after key: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: key) else {
            return nil
        }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }
        return arguments[valueIndex]
    }

    var body: some View {
        ZStack {
            RTheme.bg.ignoresSafeArea()

            if showDirectGauntlet {
                GauntletView { showDirectGauntlet = false }
                    .transition(.opacity)
            } else if let mode = activeMode {
                if mode == .dropArcade {
                    DropArcadeView {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeMode = nil
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                } else if mode == .whackArcade {
                    WhackArcadeView {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeMode = nil
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                } else if mode == .chainArcade {
                    ChainArcadeView {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeMode = nil
                        }
                    }
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                } else if mode == .gridArcade {
                    GridArcadeView {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeMode = nil
                        }
                    }
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                } else if mode == .avoidArcade {
                    AvoidArcadeView { withAnimation(.easeInOut(duration: 0.2)) { activeMode = nil } }
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                } else if mode == .memoryArcade {
                    MemoryArcadeView { withAnimation(.easeInOut(duration: 0.2)) { activeMode = nil } }
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                } else {
                    TestView(engine: engine, mode: mode) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeMode = nil
                            engine.reset()
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
            } else {
                HomeView { mode in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        activeMode = mode
                        if !mode.isArcade {
                            engine.startSession(mode: mode)
                        }
                    }
                }
                .transition(.opacity)
            }

            // First-launch onboarding overlay
            if showOnboarding {
                OnboardingView {
                    UserDefaults.standard.set(true, forKey: "didOnboard")
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        showOnboarding = false
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .zIndex(99)
            }
        }
        .onAppear {
            guard let mode = activeMode, !mode.isArcade, !didStartInitialMode else {
                return
            }
            didStartInitialMode = true
            engine.startSession(mode: mode)
        }
        .animation(.easeInOut(duration: 0.2), value: activeMode == nil)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showOnboarding)
    }
}
