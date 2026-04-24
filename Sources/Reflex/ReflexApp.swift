import SwiftUI

@main
struct ReflexApp: App {
    init() {
        UserDefaults.standard.register(defaults: [
            "hapticsEnabled": true,
            "soundEnabled": true
        ])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
