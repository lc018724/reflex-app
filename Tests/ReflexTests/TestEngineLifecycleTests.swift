import XCTest
import SwiftUI
@testable import Reflex

@MainActor
final class TestEngineLifecycleTests: XCTestCase {

    // MARK: - Session lifecycle

    func testAllErrorsFlashSessionDoneAvgAndBestAreZero() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.startSession(mode: .flash)

        for _ in 0..<TestMode.flash.trialCount {
            engine.phase = .stimulus(.goNoGo(isGo: false))
            engine.resetStimulusTime()
            engine.handleTap() // tap on no-go records error
        }
        engine.advanceTrial(ms: nil)

        guard case .sessionDone(let avg, let best, let results) = engine.phase else {
            return XCTFail("Expected sessionDone after all-errors run")
        }
        XCTAssertEqual(avg, 0, accuracy: 0.001)
        XCTAssertEqual(best, 0, accuracy: 0.001)
        XCTAssertEqual(results.count, TestMode.flash.trialCount)
        XCTAssertTrue(results.allSatisfy { $0 >= 999 })
    }

    func testStartSessionResetsResultsBetweenSessions() {
        let engine = TestEngine(automaticallyAdvances: false)

        engine.startSession(mode: .flash)
        for _ in 0..<TestMode.flash.trialCount {
            engine.phase = .stimulus(.goNoGo(isGo: false))
            engine.resetStimulusTime()
            engine.handleTap()
        }
        engine.advanceTrial(ms: nil)

        engine.startSession(mode: .colorTap)
        for _ in 0..<TestMode.colorTap.trialCount {
            engine.phase = .stimulus(.colorTap(colors: NamedColor.random(4), targetIndex: 0))
            engine.resetStimulusTime()
            engine.handleTap(data: .index(1)) // wrong tap = error
        }
        engine.advanceTrial(ms: nil)

        guard case .sessionDone(_, _, let results) = engine.phase else {
            return XCTFail("Expected sessionDone for second session")
        }
        // If startSession had not reset results, this would be 10 (5 + 5).
        XCTAssertEqual(results.count, TestMode.colorTap.trialCount)
    }

    // MARK: - Stimulus correctness, remaining branches

    func testFindCorrectIndexRecordsResult() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .find
        engine.phase = .stimulus(.find(items: ["A", "B", "C", "D"], targetIndex: 2))
        engine.resetStimulusTime()

        engine.handleTap(data: .index(2))

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after correct find tap")
        }
        XCTAssertFalse(isError)
    }

    func testFindWrongIndexRecordsError() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .find
        engine.phase = .stimulus(.find(items: ["A", "B", "C", "D"], targetIndex: 2))
        engine.resetStimulusTime()

        engine.handleTap(data: .index(0))

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after wrong find tap")
        }
        XCTAssertTrue(isError)
    }

    func testStroopMatchingColorNameRecordsResult() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .stroop
        let textColor = NamedColor.all.first { $0.name == "RED" }!
        engine.phase = .stimulus(.stroop(word: "BLUE", textColor: textColor, correctAnswer: "RED"))
        engine.resetStimulusTime()

        engine.handleTap(data: .colorName("RED"))

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after correct stroop tap")
        }
        XCTAssertFalse(isError)
    }

    func testStroopWrongColorNameRecordsError() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .stroop
        let textColor = NamedColor.all.first { $0.name == "RED" }!
        engine.phase = .stimulus(.stroop(word: "BLUE", textColor: textColor, correctAnswer: "RED"))
        engine.resetStimulusTime()

        engine.handleTap(data: .colorName("BLUE"))

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after wrong stroop tap")
        }
        XCTAssertTrue(isError)
    }

    func testReverseStroopCorrectIndexRecordsResult() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .reverseStroop
        let boxes = (0..<4).map { _ in
            StroopBox(text: "GREEN", backgroundColor: .blue, textColor: .white)
        }
        engine.phase = .stimulus(.reverseStroop(boxes: boxes, prompt: "GREEN", correctIndex: 1))
        engine.resetStimulusTime()

        engine.handleTap(data: .index(1))

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after correct reverseStroop tap")
        }
        XCTAssertFalse(isError)
    }

    func testReverseStroopWrongIndexRecordsError() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .reverseStroop
        let boxes = (0..<4).map { _ in
            StroopBox(text: "GREEN", backgroundColor: .blue, textColor: .white)
        }
        engine.phase = .stimulus(.reverseStroop(boxes: boxes, prompt: "GREEN", correctIndex: 1))
        engine.resetStimulusTime()

        engine.handleTap(data: .index(3))

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after wrong reverseStroop tap")
        }
        XCTAssertTrue(isError)
    }

    func testMathCorrectIndexRecordsResult() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .math
        engine.phase = .stimulus(.math(equation: "3 + 4", choices: [5, 7, 9, 11], correctIndex: 1))
        engine.resetStimulusTime()

        engine.handleTap(data: .index(1))

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after correct math tap")
        }
        XCTAssertFalse(isError)
    }

    func testMathWrongIndexRecordsError() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .math
        engine.phase = .stimulus(.math(equation: "3 + 4", choices: [5, 7, 9, 11], correctIndex: 1))
        engine.resetStimulusTime()

        engine.handleTap(data: .index(0))

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after wrong math tap")
        }
        XCTAssertTrue(isError)
    }

    func testOddOneOutCorrectIndexRecordsResult() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .oddOneOut
        engine.phase = .stimulus(.oddOneOut(items: ["A", "A", "B", "A"], oddIndex: 2, style: .letter))
        engine.resetStimulusTime()

        engine.handleTap(data: .index(2))

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after correct oddOneOut tap")
        }
        XCTAssertFalse(isError)
    }

    func testOddOneOutWrongIndexRecordsError() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .oddOneOut
        engine.phase = .stimulus(.oddOneOut(items: ["A", "A", "B", "A"], oddIndex: 2, style: .letter))
        engine.resetStimulusTime()

        engine.handleTap(data: .index(0))

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after wrong oddOneOut tap")
        }
        XCTAssertTrue(isError)
    }

    func testDigitMatchCorrectIndexRecordsResult() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .digitMatch
        engine.phase = .stimulus(.digitMatch(items: [3, 7, 1, 9, 5, 2], targetIndex: 4))
        engine.resetStimulusTime()

        engine.handleTap(data: .index(4))

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after correct digitMatch tap")
        }
        XCTAssertFalse(isError)
    }

    func testDigitMatchWrongIndexRecordsError() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .digitMatch
        engine.phase = .stimulus(.digitMatch(items: [3, 7, 1, 9, 5, 2], targetIndex: 4))
        engine.resetStimulusTime()

        engine.handleTap(data: .index(2))

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after wrong digitMatch tap")
        }
        XCTAssertTrue(isError)
    }

    func testSimonOppositeSideRecordsResult() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .simon
        let gold = NamedColor.all.first { $0.name == "GOLD" }!
        engine.phase = .stimulus(.simon(color: gold, stimSide: .left, correctSide: .right))
        engine.resetStimulusTime()

        engine.handleTap(data: .side(.right))

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after correct simon tap")
        }
        XCTAssertFalse(isError)
    }

    func testSimonSameSideRecordsError() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .simon
        let gold = NamedColor.all.first { $0.name == "GOLD" }!
        engine.phase = .stimulus(.simon(color: gold, stimSide: .left, correctSide: .right))
        engine.resetStimulusTime()

        engine.handleTap(data: .side(.left))

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after wrong simon tap")
        }
        XCTAssertTrue(isError)
    }
}
