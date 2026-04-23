import SwiftUI

struct ContentView: View {
    @StateObject private var engine = TestEngine()
    @State private var activeMode: TestMode? = nil

    var body: some View {
        ZStack {
            RTheme.bg.ignoresSafeArea()

            if let mode = activeMode {
                TestView(engine: engine, mode: mode) {
                    engine.reset()
                    activeMode = nil
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                HomeView { mode in
                    withAnimation(.easeInOut(duration: 0.22)) {
                        activeMode = mode
                        engine.startSession(mode: mode)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: activeMode == nil)
    }
}
