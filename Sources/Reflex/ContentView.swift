import SwiftUI

struct ContentView: View {
    @StateObject private var engine = TestEngine()
    @State private var activeMode: TestMode? = nil
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "didOnboard")

    var body: some View {
        ZStack {
            RTheme.bg.ignoresSafeArea()

            if let mode = activeMode {
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
                    ChainArcadeView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                } else if mode == .gridArcade {
                    GridArcadeView()
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
        .animation(.easeInOut(duration: 0.2), value: activeMode == nil)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showOnboarding)
    }
}
