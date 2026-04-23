import Foundation

/// Persists personal bests and session history per test mode.
final class TestStore {

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Best score per mode

    func bestMS(for mode: TestMode) -> Double? {
        let key = "best_\(mode.rawValue)"
        let v = defaults.double(forKey: key)
        return v > 0 ? v : nil
    }

    func updateBest(ms: Double, for mode: TestMode) {
        let key = "best_\(mode.rawValue)"
        let existing = defaults.double(forKey: key)
        if existing == 0 || ms < existing {
            defaults.set(ms, forKey: key)
        }
    }

    // MARK: - Session history (last 30 sessions per mode)

    func history(for mode: TestMode) -> [Double] {
        let key = "history_\(mode.rawValue)"
        return defaults.array(forKey: key) as? [Double] ?? []
    }

    func appendSession(avg: Double, for mode: TestMode) {
        let key = "history_\(mode.rawValue)"
        var h = history(for: mode)
        h.append(avg)
        if h.count > 30 { h = Array(h.suffix(30)) }
        defaults.set(h, forKey: key)
    }

    // MARK: - Total sessions

    var totalSessions: Int {
        get { defaults.integer(forKey: "totalSessions") }
        set { defaults.set(newValue, forKey: "totalSessions") }
    }
}
