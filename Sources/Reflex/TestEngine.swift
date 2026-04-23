import Foundation
import QuartzCore

@MainActor
final class TestEngine: ObservableObject {
    @Published var phase: TestPhase = .idle
    @Published var phaseID: Int = 0
    @Published var mode: TestMode = .flash

    private var stimulusTime: CFTimeInterval = 0
    private var delayTask: Task<Void, Never>?
    private var results: [Double] = []
    private var currentTrial: Int = 0

    // N-Back history
    private var nBackHistory: [String] = []

    // Sequence data
    private var currentSequence: [Int] = []

    // Double flash state
    private var flashesSeen: Int = 0

    // MARK: - Phase setter
    private func go(_ p: TestPhase) {
        phase = p
        phaseID += 1
    }

    // MARK: - Session control

    func startSession(mode: TestMode) {
        self.mode = mode
        results = []
        currentTrial = 0
        nBackHistory = []
        currentSequence = []
        flashesSeen = 0
        go(.instruction)
    }

    func dismissInstruction() {
        beginCountdown()
    }

    func reset() {
        delayTask?.cancel()
        delayTask = nil
        go(.idle)
    }

    // MARK: - Countdown

    private func beginCountdown() {
        go(.countdown(3))
        delayTask = Task {
            for i in [3, 2, 1] {
                try? await Task.sleep(nanoseconds: 600_000_000)
                guard !Task.isCancelled else { return }
                go(.countdown(i - 1))
            }
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            beginWaiting()
        }
    }

    // MARK: - Wait

    private func beginWaiting() {
        go(.waiting)
        let delay = Double.random(in: 0.8...2.5)
        delayTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            showStimulus()
        }
    }

    // MARK: - Stimulus generation

    private func showStimulus() {
        let data = generateStimulus(for: mode)
        stimulusTime = CACurrentMediaTime()

        // Sequence uses a special flow
        if case .sequence(let steps, _, _) = data {
            currentSequence = steps
            go(.stimulus(data))
            startSequencePlayback(steps: steps)
            return
        }

        // DualTrack: flash each target, then show both for tapping
        if case .dualTrack(let positions, let phase) = data {
            go(.stimulus(data))
            if case .showFirst(let idx1) = phase {
                startDualTrackSequence(positions: positions, idx1: idx1)
            }
            return
        }

        go(.stimulus(data))
    }

    private func startDualTrackSequence(positions: [DualPos], idx1: Int) {
        let targets = Array((0..<positions.count).shuffled().prefix(2))
        let t0 = targets[0], t1 = targets[1]
        delayTask = Task {
            // Flash first target briefly
            go(.stimulus(.dualTrack(positions: positions, phase: .showFirst(t0))))
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            // Flash second
            go(.stimulus(.dualTrack(positions: positions, phase: .showSecond(t1))))
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            // Now show both for tapping - start timing here
            stimulusTime = CACurrentMediaTime()
            go(.stimulus(.dualTrack(positions: positions, phase: .awaitTaps(targets))))
        }
    }

    private func generateStimulus(for mode: TestMode) -> StimulusData {
        switch mode {

        case .flash:
            return .flash

        case .fallingBall:
            return .fallingBall(index: Int.random(in: 0..<5), count: 5)

        case .antiTap:
            return .antiTap

        case .find:
            let pool = "ABCDEFGHJKLMNPQRSTUVWXYZ".map(String.init)
                + (2...9).map(String.init)
            var chosen = Array(pool.shuffled().prefix(4))
            let targetIdx = Int.random(in: 0..<4)
            return .find(items: chosen, targetIndex: targetIdx)

        case .colorTap:
            let colors = NamedColor.random(4)
            let targetIdx = Int.random(in: 0..<4)
            return .colorTap(colors: colors, targetIndex: targetIdx)

        case .oddOneOut:
            let styles: [OddStyle] = [.letter, .number, .symbol]
            let style = styles.randomElement()!
            return makeOddOneOut(style: style)

        case .goNoGo:
            return .goNoGo(isGo: Double.random(in: 0...1) > 0.25)

        case .stroop:
            let wordColor = NamedColor.all.randomElement()!
            let textColor = NamedColor.all.filter { $0 != wordColor }.randomElement()!
            return .stroop(word: wordColor.name, textColor: textColor, correctAnswer: textColor.name)

        case .reverseStroop:
            let prompt = NamedColor.all.randomElement()!
            // 4 boxes: one with text == prompt.name, others with different texts
            var others = NamedColor.all.filter { $0.name != prompt.name }.shuffled().prefix(3).map { $0 }
            let correctIndex = Int.random(in: 0..<4)
            var boxes: [StroopBox] = []
            var otherIdx = 0
            for i in 0..<4 {
                if i == correctIndex {
                    let bg = NamedColor.all.randomElement()!
                    boxes.append(StroopBox(text: prompt.name, backgroundColor: bg.color, textColor: .white))
                } else {
                    let nc = others[otherIdx]; otherIdx += 1
                    let bg = NamedColor.all.filter { $0.name != nc.name }.randomElement()!
                    boxes.append(StroopBox(text: nc.name, backgroundColor: bg.color, textColor: .white))
                }
            }
            return .reverseStroop(boxes: boxes, prompt: prompt.name, correctIndex: correctIndex)

        case .mirror:
            let shown: LRDir = Bool.random() ? .left : .right
            let correct: LRDir = shown == .left ? .right : .left
            return .mirror(shown: shown, correct: correct)

        case .math:
            let a = Int.random(in: 2...12)
            let b = Int.random(in: 2...12)
            let ops: [(String, Int)] = [("+", a+b), ("-", abs(a-b)), ("×", a*b)]
            let (op, answer) = ops.randomElement()!
            var choices = [answer]
            while choices.count < 4 {
                let noise = Int.random(in: -5...5)
                let c = answer + noise
                if c != answer && !choices.contains(c) && c > 0 { choices.append(c) }
            }
            choices.shuffle()
            let ci = choices.firstIndex(of: answer)!
            return .math(equation: "\(a) \(op) \(b)", choices: choices, correctIndex: ci)

        case .sequence:
            let steps = (0..<4).map { _ in Int.random(in: 0..<4) }
            return .sequence(steps: steps, isPlayback: true, inputSoFar: [])

        case .nBack:
            let symbols = ["A","B","C","D","E","F","G","H"]
            let shouldTap = !nBackHistory.isEmpty && Double.random(in: 0...1) > 0.5
            let symbol: String
            if shouldTap, let last = nBackHistory.last {
                symbol = last
            } else {
                symbol = symbols.filter { $0 != nBackHistory.last }.randomElement()!
            }
            nBackHistory.append(symbol)
            if nBackHistory.count > 2 { nBackHistory.removeFirst() }
            return .nBack(symbol: symbol, shouldTap: shouldTap && nBackHistory.count >= 2)

        case .peripheral:
            // Edges only: pick one of 4 edges, then random position on that edge
            let edge = Int.random(in: 0..<4)
            let pos: (CGFloat, CGFloat)
            switch edge {
            case 0: pos = (CGFloat.random(in: 0.1...0.9), 0.05)  // top
            case 1: pos = (CGFloat.random(in: 0.1...0.9), 0.95)  // bottom
            case 2: pos = (0.05, CGFloat.random(in: 0.2...0.8))  // left
            default: pos = (0.95, CGFloat.random(in: 0.2...0.8)) // right
            }
            return .peripheral(normX: pos.0, normY: pos.1)

        case .doubleFlash:
            flashesSeen = 0
            return .doubleFlash(flashCount: 0)

        case .digitMatch:
            var digits = (0..<6).map { _ in Int.random(in: 1...9) }
            let target = digits.randomElement()!
            let targetIdx = digits.firstIndex(of: target)!
            return .digitMatch(items: digits, targetIndex: targetIdx)

        case .simon:
            let colors: [NamedColor] = [
                NamedColor(name: "GOLD", color: RTheme.gold),
                NamedColor(name: "WHITE", color: .white)
            ]
            let color = colors.randomElement()!
            let stimSide: LRDir = Bool.random() ? .left : .right
            // correct = opposite of stimulus position
            let correct: LRDir = stimSide == .left ? .right : .left
            return .simon(color: color, stimSide: stimSide, correctSide: correct)

        case .speedSort:
            var numbers = (0..<4).map { _ in Int.random(in: 10...99) }
            let maxVal = numbers.max()!
            let maxIdx = numbers.firstIndex(of: maxVal)!
            return .speedSort(numbers: numbers, highestIndex: maxIdx)

        case .rhythm:
            // Rhythm uses the flash stimulus with a different instruction
            return .flash

        case .dualTrack:
            let positions = (0..<4).map { _ in
                DualPos(x: CGFloat.random(in: 0.15...0.85),
                        y: CGFloat.random(in: 0.2...0.8))
            }
            let targets = Array((0..<4).shuffled().prefix(2))
            return .dualTrack(positions: positions, phase: .showFirst(targets[0]))

        case .dropArcade:
            return .flash // Arcade mode bypasses TestEngine entirely; fallback just in case
        }
    }

    // MARK: - Sequence playback

    private func startSequencePlayback(steps: [Int]) {
        stimulusTime = CACurrentMediaTime()
        delayTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            for (i, step) in steps.enumerated() {
                guard !Task.isCancelled else { return }
                go(.stimulus(.sequence(steps: steps, isPlayback: true, inputSoFar: [])))
                // Highlight each step
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
            }
            // Switch to input phase
            guard !Task.isCancelled else { return }
            stimulusTime = CACurrentMediaTime()
            go(.sequenceInput(steps: steps, inputSoFar: [], targetSteps: steps))
        }
    }

    // MARK: - Input handling

    func handleTap(data: TapData = .simple) {
        switch phase {

        case .waiting:
            // Too early
            if mode == .doubleFlash { break } // doubleFlash handled separately
            go(.tooSoon)
            delayTask?.cancel()
            delayTask = Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                beginWaiting()
            }

        case .stimulus(let stim):
            let elapsed = (CACurrentMediaTime() - stimulusTime) * 1000

            switch stim {
            case .goNoGo(let isGo):
                if isGo { recordResult(ms: elapsed) }
                else { recordError() }

            case .mirror(_, let correct):
                if case .side(let s) = data, s == correct { recordResult(ms: elapsed) }
                else { recordError() }

            case .colorTap(let colors, let targetIndex):
                if case .index(let i) = data, i == targetIndex { recordResult(ms: elapsed) }
                else { recordError() }

            case .find(_, let targetIndex):
                if case .index(let i) = data, i == targetIndex { recordResult(ms: elapsed) }
                else { recordError() }

            case .stroop(_, _, let correct):
                if case .colorName(let n) = data, n == correct { recordResult(ms: elapsed) }
                else { recordError() }

            case .reverseStroop(_, _, let correctIndex):
                if case .index(let i) = data, i == correctIndex { recordResult(ms: elapsed) }
                else { recordError() }

            case .math(_, _, let correctIndex):
                if case .index(let i) = data, i == correctIndex { recordResult(ms: elapsed) }
                else { recordError() }

            case .oddOneOut(_, let oddIndex, _):
                if case .index(let i) = data, i == oddIndex { recordResult(ms: elapsed) }
                else { recordError() }

            case .digitMatch(_, let targetIndex):
                if case .index(let i) = data, i == targetIndex { recordResult(ms: elapsed) }
                else { recordError() }

            case .speedSort(_, let highestIndex):
                if case .index(let i) = data, i == highestIndex { recordResult(ms: elapsed) }
                else { recordError() }

            case .simon(_, _, let correct):
                if case .side(let s) = data, s == correct { recordResult(ms: elapsed) }
                else { recordError() }

            case .nBack(_, let shouldTap):
                if shouldTap { recordResult(ms: elapsed) }
                else { recordError() }

            case .fallingBall(let idx, _):
                if case .index(let i) = data, i == idx { recordResult(ms: elapsed) }
                else { recordError() }

            case .peripheral:
                recordResult(ms: elapsed)

            case .dualTrack:
                recordResult(ms: elapsed)

            default:
                // flash, antiTap
                recordResult(ms: elapsed)
            }

        case .tooSoon:
            break

        default:
            break
        }
    }

    func handleNoTap() {
        guard case .stimulus(let stim) = phase else { return }
        switch stim {
        case .goNoGo(let isGo):
            if isGo { recordError() } else { advanceTrial(ms: nil) }
        case .nBack(_, let shouldTap):
            if shouldTap { recordError() } else { advanceTrial(ms: nil) }
        default:
            recordError()
        }
    }

    func handleDoubleFlashTap() {
        guard case .stimulus(.doubleFlash(let count)) = phase else { return }
        let elapsed = (CACurrentMediaTime() - stimulusTime) * 1000
        if count >= 2 {
            recordResult(ms: elapsed)
        } else {
            // Tapped too early (only 1 flash)
            recordError()
        }
    }

    func advanceDoubleFlash() {
        flashesSeen += 1
        guard case .stimulus = phase else { return }
        go(.stimulus(.doubleFlash(flashCount: flashesSeen)))
        stimulusTime = CACurrentMediaTime()
    }

    func handleSequenceInput(index: Int) {
        guard case .sequenceInput(let steps, var inputSoFar, let target) = phase else { return }
        let elapsed = (CACurrentMediaTime() - stimulusTime) * 1000
        inputSoFar.append(index)

        if inputSoFar[inputSoFar.count - 1] != target[inputSoFar.count - 1] {
            // Wrong tap
            recordError()
            return
        }

        if inputSoFar.count == target.count {
            recordResult(ms: elapsed)
        } else {
            go(.sequenceInput(steps: steps, inputSoFar: inputSoFar, targetSteps: target))
        }
    }

    // MARK: - Result recording

    private func recordResult(ms: Double) {
        currentTrial += 1
        results.append(ms)
        let t = currentTrial; let total = mode.trialCount
        go(.result(ms: ms, trial: t, total: total, isError: false))
        scheduleAdvance(ms: ms)
    }

    private func recordError() {
        currentTrial += 1
        results.append(999)
        let t = currentTrial; let total = mode.trialCount
        go(.result(ms: -1, trial: t, total: total, isError: true))
        scheduleAdvance(ms: nil)
    }

    private func scheduleAdvance(ms: Double?) {
        delayTask = Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            advanceTrial(ms: ms)
        }
    }

    func advanceTrial(ms: Double?) {
        if currentTrial >= mode.trialCount {
            let valid = results.filter { $0 < 999 }
            let avg = valid.isEmpty ? 0 : valid.reduce(0, +) / Double(valid.count)
            let best = valid.min() ?? 0
            go(.sessionDone(avg: avg, best: best, results: results))
        } else {
            beginWaiting()
        }
    }

    // MARK: - Helpers

    private func makeOddOneOut(style: OddStyle) -> StimulusData {
        let oddIndex = Int.random(in: 0..<4)
        switch style {
        case .letter:
            let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ".map(String.init)
            let main = letters.randomElement()!
            var items = Array(repeating: main, count: 4)
            items[oddIndex] = letters.filter { $0 != main }.randomElement()!
            return .oddOneOut(items: items, oddIndex: oddIndex, style: .letter)
        case .number:
            let n = Int.random(in: 2...9)
            var items = Array(repeating: String(n), count: 4)
            items[oddIndex] = String((2...9).filter { $0 != n }.randomElement()!)
            return .oddOneOut(items: items, oddIndex: oddIndex, style: .number)
        case .symbol:
            let symbols = ["★","●","■","▲","◆","✦"]
            let main = symbols.randomElement()!
            var items = Array(repeating: main, count: 4)
            items[oddIndex] = symbols.filter { $0 != main }.randomElement()!
            return .oddOneOut(items: items, oddIndex: oddIndex, style: .symbol)
        default:
            return makeOddOneOut(style: .letter)
        }
    }
}

// MARK: - Tap data

enum TapData {
    case simple
    case index(Int)
    case side(LRDir)
    case colorName(String)
}
