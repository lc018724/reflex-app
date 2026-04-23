import Foundation
import QuartzCore

// MARK: - Test Mode

enum TestMode: String, CaseIterable, Identifiable {
    case simpleTap  = "TAP"
    case choice     = "CHOOSE"
    case suppress   = "SUPPRESS"

    var id: String { rawValue }

    var title: String { rawValue }

    var subtitle: String {
        switch self {
        case .simpleTap: return "Pure reflex speed"
        case .choice:    return "Decision + reflex"
        case .suppress:  return "Inhibitory control"
        }
    }

    var description: String {
        switch self {
        case .simpleTap:
            return "Screen flashes gold. Tap the moment you see it. No tricks."
        case .choice:
            return "A circle appears left or right. Tap the correct side instantly."
        case .suppress:
            return "Tap every circle — but not the X. Miss an X and you lose."
        }
    }

    var trialCount: Int { 5 }
}

// MARK: - Stimulus (Choice + Suppress)

enum Stimulus {
    case go(side: Side)   // choice: left/right; suppress: just "tap"
    case noGo             // suppress only

    enum Side { case left, right }
}

// MARK: - Phase

enum TestPhase {
    case idle
    case countdown(Int)   // 3, 2, 1
    case waiting          // random delay before stimulus
    case stimulus(Stimulus)
    case tooSoon          // tapped during waiting phase
    case result(ms: Double, trial: Int, total: Int)
    case sessionDone(avg: Double, best: Double, results: [Double])
}

// MARK: - TestEngine

@MainActor
final class TestEngine: ObservableObject {
    @Published var phase: TestPhase = .idle
    @Published var phaseID: Int = 0   // increments on every phase change for onChange
    @Published var mode: TestMode = .simpleTap

    private var stimulusTime: CFTimeInterval = 0
    private var delayTask: Task<Void, Never>?
    private var results: [Double] = []
    private var currentTrial: Int = 0

    // MARK: - Phase setter

    private func setPhase(_ p: TestPhase) {
        phase = p
        phaseID += 1
    }

    // MARK: - Start session

    func startSession(mode: TestMode) {
        self.mode = mode
        results = []
        currentTrial = 0
        beginCountdown()
    }

    func reset() {
        delayTask?.cancel()
        delayTask = nil
        setPhase(.idle)
    }

    // MARK: - Countdown

    private func beginCountdown() {
        setPhase(.countdown(3))
        delayTask = Task {
            for tick in stride(from: 3, through: 1, by: -1) {
                try? await Task.sleep(nanoseconds: 600_000_000)
                guard !Task.isCancelled else { return }
                setPhase(.countdown(tick - 1 == 0 ? 0 : tick - 1))
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            beginWaiting()
        }
    }

    // MARK: - Waiting (random delay)

    private func beginWaiting() {
        setPhase(.waiting)
        let delay = Double.random(in: 0.8...2.8)
        delayTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            showStimulus()
        }
    }

    // MARK: - Stimulus

    private func showStimulus() {
        let stim: Stimulus
        switch mode {
        case .simpleTap:
            stim = .go(side: .left) // side unused for simpleTap
        case .choice:
            stim = .go(side: Bool.random() ? .left : .right)
        case .suppress:
            // 25% chance of no-go
            stim = Double.random(in: 0...1) < 0.25 ? .noGo : .go(side: .left)
        }
        stimulusTime = CACurrentMediaTime()
        setPhase(.stimulus(stim))
    }

    // MARK: - Input handling

    func handleTap(side: Stimulus.Side? = nil) {
        switch phase {
        case .waiting:
            setPhase(.tooSoon)
            delayTask?.cancel()
            delayTask = Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard !Task.isCancelled else { return }
                beginWaiting()
            }

        case .stimulus(let stim):
            let elapsed = (CACurrentMediaTime() - stimulusTime) * 1000 // ms

            switch stim {
            case .noGo:
                // Tapping on no-go = failure, penalise with 999ms phantom
                recordResult(ms: 999, isError: true)
            case .go(let stimSide):
                if mode == .choice, let tapped = side, tapped != stimSide {
                    // Wrong side in choice mode
                    recordResult(ms: 999, isError: true)
                } else {
                    recordResult(ms: elapsed, isError: false)
                }
            }

        case .tooSoon:
            break // ignore taps while showing "too soon"

        default:
            break
        }
    }

    func handleNoTap() {
        // Called when suppress trial timer expires without a tap
        guard case .stimulus(let stim) = phase else { return }
        switch stim {
        case .noGo:
            // Correctly withheld — no time to record (not a RT trial)
            advanceTrial(ms: nil)
        case .go:
            // Missed a go stimulus — record as very slow
            recordResult(ms: 999, isError: true)
        }
    }

    // MARK: - Result recording

    private func recordResult(ms: Double, isError: Bool) {
        currentTrial += 1
        let value = isError ? 999.0 : ms
        results.append(value)

        let trial = currentTrial
        let total = mode.trialCount
        setPhase(.result(ms: isError ? -1 : ms, trial: trial, total: total))

        delayTask = Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            advanceTrial(ms: isError ? nil : ms)
        }
    }

    private func advanceTrial(ms: Double?) {
        if currentTrial >= mode.trialCount {
            let valid = results.filter { $0 < 999 }
            let avg = valid.isEmpty ? 0 : valid.reduce(0, +) / Double(valid.count)
            let best = valid.min() ?? 0
            setPhase(.sessionDone(avg: avg, best: best, results: results))
        } else {
            beginWaiting()
        }
    }
}

// MARK: - Population benchmarks

struct ReactionBenchmarks {
    /// Returns a 0-100 percentile (higher = faster than more people).
    static func percentile(ms: Double) -> Int {
        // Based on published human RT distributions (visual simple RT)
        // Mean ~250ms, SD ~50ms. We map onto a rough percentile curve.
        switch ms {
        case ..<150: return 99
        case 150..<175: return 95
        case 175..<200: return 88
        case 200..<220: return 78
        case 220..<240: return 65
        case 240..<260: return 50
        case 260..<280: return 38
        case 280..<310: return 25
        case 310..<350: return 15
        case 350..<400: return 8
        default: return 3
        }
    }

    /// Driving distance at 60mph before braking begins.
    static func drivingFeet(ms: Double) -> Double {
        let mph: Double = 60
        let fps = mph * 5280 / 3600  // feet per second
        return fps * (ms / 1000)
    }

    static func label(ms: Double) -> String {
        switch ms {
        case ..<175: return "Elite athlete"
        case 175..<210: return "Above average"
        case 210..<260: return "Average"
        case 260..<320: return "Below average"
        default:        return "Needs improvement"
        }
    }
}
