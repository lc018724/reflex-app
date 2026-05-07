import XCTest
@testable import Reflex

@MainActor
final class TestEngineInputTests: XCTestCase {

    // MARK: - Too-soon handling

    func testTapWhileWaitingGoesToTooSoon() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .flash
        engine.phase = .waiting

        engine.handleTap()

        if case .tooSoon = engine.phase {
        } else {
            XCTFail("Expected tooSoon phase after tap during waiting")
        }
    }

    func testTapWhileWaitingInDoubleFlashIsIgnored() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .doubleFlash
        engine.phase = .waiting

        engine.handleTap()

        if case .waiting = engine.phase {
        } else {
            XCTFail("Double-flash waiting must not transition on plain tap")
        }
    }

    func testTapWhileTooSoonIsNoOp() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .flash
        engine.phase = .tooSoon

        engine.handleTap()

        if case .tooSoon = engine.phase {
        } else {
            XCTFail("tooSoon must remain tooSoon on extra tap")
        }
    }

    // MARK: - Stimulus correctness, indexed

    func testColorTapMatchingTargetRecordsResult() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .colorTap
        let colors = NamedColor.random(4)
        engine.phase = .stimulus(.colorTap(colors: colors, targetIndex: 2))
        engine.resetStimulusTime()

        engine.handleTap(data: .index(2))

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after correct color tap")
        }
        XCTAssertFalse(isError)
    }

    func testColorTapWrongIndexRecordsError() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .colorTap
        let colors = NamedColor.random(4)
        engine.phase = .stimulus(.colorTap(colors: colors, targetIndex: 2))
        engine.resetStimulusTime()

        engine.handleTap(data: .index(0))

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after wrong color tap")
        }
        XCTAssertTrue(isError)
    }

    func testSpeedSortHighestIndexIsCorrectAndOthersAreErrors() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .speedSort
        engine.phase = .stimulus(.speedSort(numbers: [10, 99, 42, 30], highestIndex: 1))
        engine.resetStimulusTime()

        engine.handleTap(data: .index(1))
        guard case .result(_, _, _, let firstError) = engine.phase else {
            return XCTFail("Expected result after correct speedSort tap")
        }
        XCTAssertFalse(firstError)

        engine.phase = .stimulus(.speedSort(numbers: [10, 99, 42, 30], highestIndex: 1))
        engine.resetStimulusTime()
        engine.handleTap(data: .index(0))
        guard case .result(_, _, _, let secondError) = engine.phase else {
            return XCTFail("Expected result after wrong speedSort tap")
        }
        XCTAssertTrue(secondError)
    }

    // MARK: - Mirror (side-based) and simon (side-based)

    func testMirrorTapOppositeSideIsCorrect() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .mirror
        engine.phase = .stimulus(.mirror(shown: .left, correct: .right))
        engine.resetStimulusTime()

        engine.handleTap(data: .side(.right))

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result after correct mirror tap")
        }
        XCTAssertFalse(isError)
    }

    func testMirrorTapSameSideIsError() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .mirror
        engine.phase = .stimulus(.mirror(shown: .left, correct: .right))
        engine.resetStimulusTime()

        engine.handleTap(data: .side(.left))

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result after wrong mirror tap")
        }
        XCTAssertTrue(isError)
    }

    // MARK: - N-Back tap and no-tap branches

    func testNBackShouldTapHandledTapIsCorrect() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .nBack
        engine.phase = .stimulus(.nBack(symbol: "A", shouldTap: true))
        engine.resetStimulusTime()

        engine.handleTap()

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result on shouldTap tap")
        }
        XCTAssertFalse(isError)
    }

    func testNBackShouldNotTapHandledTapIsError() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .nBack
        engine.phase = .stimulus(.nBack(symbol: "A", shouldTap: false))
        engine.resetStimulusTime()

        engine.handleTap()

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result on shouldNotTap tap")
        }
        XCTAssertTrue(isError)
    }

    func testNBackShouldTapNoTapIsError() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .nBack
        engine.phase = .stimulus(.nBack(symbol: "A", shouldTap: true))

        engine.handleNoTap()

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after missed shouldTap")
        }
        XCTAssertTrue(isError)
    }

    func testNBackShouldNotTapNoTapAdvancesWithoutResult() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .nBack
        engine.phase = .stimulus(.nBack(symbol: "A", shouldTap: false))

        engine.handleNoTap()

        // CorrectNoTap goes directly to advanceTrial which schedules the next wait.
        // It must not produce a .result phase.
        if case .result = engine.phase {
            XCTFail("CorrectNoTap must not record a result")
        }
    }

    // MARK: - Double-flash

    func testDoubleFlashTapBeforeSecondFlashIsError() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .doubleFlash
        engine.phase = .stimulus(.doubleFlash(flashCount: 1))
        engine.resetStimulusTime()

        engine.handleDoubleFlashTap()

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after early double-flash tap")
        }
        XCTAssertTrue(isError)
    }

    func testDoubleFlashTapAfterTwoFlashesIsCorrect() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .doubleFlash
        engine.phase = .stimulus(.doubleFlash(flashCount: 2))
        engine.resetStimulusTime()

        engine.handleDoubleFlashTap()

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after correct double-flash tap")
        }
        XCTAssertFalse(isError)
    }

    // MARK: - Sequence input

    func testSequenceInputAccumulatesAndCompletesOnLastCorrectTap() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .sequence
        let target = [0, 1, 2]
        engine.phase = .sequenceInput(steps: target, inputSoFar: [], targetSteps: target)
        engine.resetStimulusTime()

        engine.handleSequenceInput(index: 0)
        if case .sequenceInput(_, let after1, _) = engine.phase {
            XCTAssertEqual(after1, [0])
        } else {
            XCTFail("Expected sequenceInput phase after first correct tap")
        }

        engine.handleSequenceInput(index: 1)
        if case .sequenceInput(_, let after2, _) = engine.phase {
            XCTAssertEqual(after2, [0, 1])
        } else {
            XCTFail("Expected sequenceInput phase after second correct tap")
        }

        engine.handleSequenceInput(index: 2)
        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after final correct tap")
        }
        XCTAssertFalse(isError)
    }

    func testSequenceInputWrongTapImmediatelyErrors() {
        let engine = TestEngine(automaticallyAdvances: false)
        engine.mode = .sequence
        let target = [0, 1, 2]
        engine.phase = .sequenceInput(steps: target, inputSoFar: [], targetSteps: target)
        engine.resetStimulusTime()

        engine.handleSequenceInput(index: 3)

        guard case .result(_, _, _, let isError) = engine.phase else {
            return XCTFail("Expected result phase after wrong sequence tap")
        }
        XCTAssertTrue(isError)
    }
}
