import XCTest
@testable import Reflex

final class ReactionBenchmarksTests: XCTestCase {

    // MARK: label(ms:)

    func testLabelEliteBoundary() {
        XCTAssertEqual(ReactionBenchmarks.label(ms: 100), "Elite")
        XCTAssertEqual(ReactionBenchmarks.label(ms: 149.999), "Elite")
        XCTAssertEqual(ReactionBenchmarks.label(ms: 150), "Exceptional")
    }

    func testLabelExceptionalBoundary() {
        XCTAssertEqual(ReactionBenchmarks.label(ms: 150), "Exceptional")
        XCTAssertEqual(ReactionBenchmarks.label(ms: 174.999), "Exceptional")
        XCTAssertEqual(ReactionBenchmarks.label(ms: 175), "Fast")
    }

    func testLabelFastBoundary() {
        XCTAssertEqual(ReactionBenchmarks.label(ms: 175), "Fast")
        XCTAssertEqual(ReactionBenchmarks.label(ms: 199.999), "Fast")
        XCTAssertEqual(ReactionBenchmarks.label(ms: 200), "Above Average")
    }

    func testLabelAboveAverageBoundary() {
        XCTAssertEqual(ReactionBenchmarks.label(ms: 200), "Above Average")
        XCTAssertEqual(ReactionBenchmarks.label(ms: 229.999), "Above Average")
        XCTAssertEqual(ReactionBenchmarks.label(ms: 230), "Average")
    }

    func testLabelAverageBoundary() {
        XCTAssertEqual(ReactionBenchmarks.label(ms: 230), "Average")
        XCTAssertEqual(ReactionBenchmarks.label(ms: 269.999), "Average")
        XCTAssertEqual(ReactionBenchmarks.label(ms: 270), "Below Average")
    }

    func testLabelBelowAverageBoundary() {
        XCTAssertEqual(ReactionBenchmarks.label(ms: 270), "Below Average")
        XCTAssertEqual(ReactionBenchmarks.label(ms: 319.999), "Below Average")
        XCTAssertEqual(ReactionBenchmarks.label(ms: 320), "Slow")
    }

    func testLabelSlowExtremes() {
        XCTAssertEqual(ReactionBenchmarks.label(ms: 320), "Slow")
        XCTAssertEqual(ReactionBenchmarks.label(ms: 1000), "Slow")
        XCTAssertEqual(ReactionBenchmarks.label(ms: 9999), "Slow")
    }

    // MARK: percentile(ms:)

    func testPercentileAtPopulationMeanIsFifty() {
        // At mean (250ms), z=0, CDF=0.5, so percentile should be 50
        XCTAssertEqual(ReactionBenchmarks.percentile(ms: 250), 50)
    }

    func testPercentileFasterIsHigher() {
        let p150 = ReactionBenchmarks.percentile(ms: 150)
        let p200 = ReactionBenchmarks.percentile(ms: 200)
        let p250 = ReactionBenchmarks.percentile(ms: 250)
        let p300 = ReactionBenchmarks.percentile(ms: 300)
        XCTAssertGreaterThan(p150, p200)
        XCTAssertGreaterThan(p200, p250)
        XCTAssertGreaterThan(p250, p300)
    }

    func testPercentileClampedToOneAndNinetyNine() {
        // Extremely fast or slow times should clamp, not overflow
        let pSuperFast = ReactionBenchmarks.percentile(ms: 50)
        let pSuperSlow = ReactionBenchmarks.percentile(ms: 1000)
        XCTAssertGreaterThanOrEqual(pSuperFast, 1)
        XCTAssertLessThanOrEqual(pSuperFast, 99)
        XCTAssertGreaterThanOrEqual(pSuperSlow, 1)
        XCTAssertLessThanOrEqual(pSuperSlow, 99)
        XCTAssertEqual(pSuperFast, 99)
        XCTAssertEqual(pSuperSlow, 1)
    }

    func testPercentileApproxOneSDFaster() {
        // 200ms is 1 SD below mean, ~84th percentile
        let p = ReactionBenchmarks.percentile(ms: 200)
        XCTAssertGreaterThanOrEqual(p, 82)
        XCTAssertLessThanOrEqual(p, 86)
    }

    func testPercentileApproxOneSDSlower() {
        // 300ms is 1 SD above mean, ~16th percentile
        let p = ReactionBenchmarks.percentile(ms: 300)
        XCTAssertGreaterThanOrEqual(p, 14)
        XCTAssertLessThanOrEqual(p, 18)
    }

    // MARK: drivingFeet(ms:)

    func testDrivingFeetAtZeroMs() {
        XCTAssertEqual(ReactionBenchmarks.drivingFeet(ms: 0), 0, accuracy: 1e-9)
    }

    func testDrivingFeetAtOneSecond() {
        // 1000ms at 88 ft/s = 88 ft
        XCTAssertEqual(ReactionBenchmarks.drivingFeet(ms: 1000), 88, accuracy: 1e-9)
    }

    func testDrivingFeetAtTypicalReaction() {
        // 250ms at 88 ft/s = 22 ft
        XCTAssertEqual(ReactionBenchmarks.drivingFeet(ms: 250), 22, accuracy: 1e-9)
    }

    func testDrivingFeetIsLinearInTime() {
        // Doubling time should double distance
        let d100 = ReactionBenchmarks.drivingFeet(ms: 100)
        let d200 = ReactionBenchmarks.drivingFeet(ms: 200)
        XCTAssertEqual(d200, d100 * 2, accuracy: 1e-9)
    }
}
