import SwiftUI

struct ContentView: View {
    @StateObject private var engine = TestEngine()
    @State private var activeMode: TestMode? = nil

    var body: some View {
        ZStack {
            RTheme.bg.ignoresSafeArea()

            if let mode = activeMode {
                if mode.isArcade {
                    DropArcadeView {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeMode = nil
                        }
                    }
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
        }
        .animation(.easeInOut(duration: 0.2), value: activeMode == nil)
    }
}
