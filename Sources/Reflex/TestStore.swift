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

    // MARK: - Daily streak

    /// Returns the current streak (consecutive calendar days with at least one session).
    var streak: Int {
        get { defaults.integer(forKey: "streak") }
        set { defaults.set(newValue, forKey: "streak") }
    }

    /// ISO date string of the last session day.
    private var lastSessionDay: String? {
        get { defaults.string(forKey: "lastSessionDay") }
        set { defaults.set(newValue, forKey: "lastSessionDay") }
    }

    /// Call after each session completes to update streak.
    func recordSessionDay() {
        let today = isoDay(Date())
        guard let last = lastSessionDay else {
            // First ever session
            streak = 1
            lastSessionDay = today
            return
        }
        if last == today {
            // Already recorded today, no change
            return
        }
        let yesterday = isoDay(Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        if last == yesterday {
            streak += 1
        } else {
            streak = 1  // Gap — reset
        }
        lastSessionDay = today
    }

    private func isoDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: - Arcade high scores

    func highScore(for mode: TestMode) -> Int? {
        let key: String
        switch mode {
        case .dropArcade:   key = "dropArcade_highScore"
        case .whackArcade:  key = "whackArcade_highScore"
        case .chainArcade:  key = "chainArcade_highScore"
        case .gridArcade:   key = "gridArcade_highScore"
        case .avoidArcade:  key = "avoidArcade_highScore"
        case .memoryArcade: key = "memoryArcade_highScore"
        default: return nil
        }
        let v = defaults.integer(forKey: key)
        return v > 0 ? v : nil
    }

    // MARK: - Reset

    func resetAll() {
        // Clear all mode bests + history
        let allModes = TestMode.allCases
        for mode in allModes {
            defaults.removeObject(forKey: "best_\(mode.rawValue)")
            defaults.removeObject(forKey: "history_\(mode.rawValue)")
        }
        defaults.removeObject(forKey: "totalSessions")
        defaults.removeObject(forKey: "streak")
        defaults.removeObject(forKey: "lastSessionDay")
        defaults.removeObject(forKey: "dropArcade_highScore")
        defaults.removeObject(forKey: "whackArcade_highScore")
        defaults.removeObject(forKey: "chainArcade_highScore")
        defaults.removeObject(forKey: "gridArcade_highScore")
        defaults.removeObject(forKey: "avoidArcade_highScore")
        defaults.removeObject(forKey: "memoryArcade_highScore")
        defaults.removeObject(forKey: "gauntlet_bestAvg")
    }

    // MARK: - Daily challenge completion

    private func dailyChallengeKey(for date: Date = Date()) -> String {
        "daily_done_\(isoDay(date))"
    }

    /// Returns true if the given mode was completed as today's daily challenge.
    func isDailyChallengeCompletedToday(mode: TestMode) -> Bool {
        defaults.string(forKey: dailyChallengeKey()) == mode.rawValue
    }

    /// Records that today's daily challenge was completed with the given mode.
    func markDailyChallengeCompleted(mode: TestMode) {
        defaults.set(mode.rawValue, forKey: dailyChallengeKey())
    }


    var gauntletBestAvg: Double? {
        get {
            let v = defaults.double(forKey: "gauntlet_bestAvg")
            return v > 0 ? v : nil
        }
    }

    func updateGauntletBest(avg: Double) {
        let existing = defaults.double(forKey: "gauntlet_bestAvg")
        if existing == 0 || avg < existing {
            defaults.set(avg, forKey: "gauntlet_bestAvg")
        }
    }
}
