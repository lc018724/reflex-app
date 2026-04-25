import XCTest
@testable import Reflex

@MainActor
final class TestEngineTests: XCTestCase {
    func testStartSessionShowsInstructionAndResetReturnsIdle() {
        let engine = TestEngine(automaticallyAdvances: false)

        engine.startSession(mode: .stroop)

        XCTAssertEqual(engine.mode, .stroop)
        if case .instruction = engine.phase {
        } else {
            XCTFail("Expected instruction phase")
        }

        engine.dismissInstruction()
        if case .countdown(let value) = engine.phase {
            XCTAssertEqual(value, 3)
        } else {
            XCTFail("Expected countdown phase")
        }

        engine.reset()
        if case .idle = engine.phase {
        } else {
            XCTFail("Expected idle phase")
        }
    }

    func testStimulusTimingUsesResetMoment() async throws {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .flash
        engine.phase = .stimulus(.flash)
        engine.resetStimulusTime()

        try await Task.sleep(nanoseconds: 25_000_000)
        engine.handleTap()

        guard case .result(let ms, let trial, let total, let isError) = engine.phase else {
            return XCTFail("Expected timed result phase")
        }
        XCTAssertFalse(isError)
        XCTAssertEqual(trial, 1)
        XCTAssertEqual(total, TestMode.flash.trialCount)
        XCTAssertGreaterThanOrEqual(ms, 15)
        XCTAssertLessThan(ms, 250)
    }

    func testSessionSummaryAveragesOnlyValidTapResults() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .flash

        engine.phase = .stimulus(.flash)
        engine.resetStimulusTime()
        engine.handleTap()

        guard case .result(let firstMS, _, _, false) = engine.phase else {
            return XCTFail("Expected first valid result")
        }

        for _ in 0..<4 {
            engine.phase = .stimulus(.goNoGo(isGo: false))
            engine.resetStimulusTime()
            engine.handleTap()
        }

        engine.advanceTrial(ms: nil)

        guard case .sessionDone(let avg, let best, let results) = engine.phase else {
            return XCTFail("Expected session summary")
        }
        XCTAssertEqual(results.count, TestMode.flash.trialCount)
        XCTAssertEqual(results.filter { $0 >= 999 }.count, 4)
        XCTAssertEqual(avg, firstMS, accuracy: 1)
        XCTAssertEqual(best, firstMS, accuracy: 1)
    }

    func testRapidTapProducesNonNegativeResult() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .flash
        engine.phase = .stimulus(.flash)
        engine.resetStimulusTime()

        engine.handleTap()

        guard case .result(let ms, _, _, false) = engine.phase else {
            return XCTFail("Expected rapid tap result")
        }
        XCTAssertGreaterThanOrEqual(ms, 0)
        XCTAssertLessThan(ms, 100)
    }

    func testCorrectNoTapTrialsCompleteNoGoSession() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .goNoGo

        for _ in 0..<TestMode.goNoGo.trialCount {
            engine.phase = .stimulus(.goNoGo(isGo: false))
            engine.handleNoTap()
        }

        if case .sessionDone = engine.phase {
        } else {
            XCTFail("Expected correct no-tap trials to complete the session")
        }
    }
}
