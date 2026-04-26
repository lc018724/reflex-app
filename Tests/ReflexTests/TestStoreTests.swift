import XCTest
@testable import Reflex

final class TestStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var store: TestStore!

    override func setUp() {
        super.setUp()
        suiteName = "ReflexTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = TestStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testBestScorePersistsAndOnlyImproves() {
        store.updateBest(ms: 320, for: .flash)
        store.updateBest(ms: 360, for: .flash)
        store.updateBest(ms: 280, for: .flash)

        let freshStore = TestStore(defaults: defaults)
        XCTAssertEqual(freshStore.bestMS(for: .flash), 280)
    }

    func testInvalidBestScoreDoesNotBlockFutureValidBest() {
        store.updateBest(ms: -1, for: .flash)
        store.updateBest(ms: 240, for: .flash)

        XCTAssertEqual(store.bestMS(for: .flash), 240)
    }

    func testHistoryRoundTripIsModeScopedAndTrimmedToThirty() {
        for i in 1...35 {
            store.appendSession(avg: Double(i), for: .flash)
        }
        store.appendSession(avg: 800, for: .stroop)

        let flashHistory = TestStore(defaults: defaults).history(for: .flash)
        XCTAssertEqual(flashHistory.count, 30)
        XCTAssertEqual(flashHistory.first, 6)
        XCTAssertEqual(flashHistory.last, 35)
        XCTAssertEqual(store.history(for: .stroop), [800])
    }

    func testResetAllClearsScoresHistoryAndCounters() {
        store.updateBest(ms: 220, for: .flash)
        store.appendSession(avg: 230, for: .flash)
        store.totalSessions = 4
        store.streak = 3
        defaults.set(17, forKey: "dropArcade_highScore")
        store.updateGauntletBest(avg: 410)

        store.resetAll()

        XCTAssertNil(store.bestMS(for: .flash))
        XCTAssertEqual(store.history(for: .flash), [])
        XCTAssertEqual(store.totalSessions, 0)
        XCTAssertEqual(store.streak, 0)
        XCTAssertNil(store.highScore(for: .dropArcade))
        XCTAssertNil(store.gauntletBestAvg)
        XCTAssertEqual(store.gauntletHistory, [])
    }

    func testArcadeHighScoresAndGauntletBestRoundTrip() {
        defaults.set(12, forKey: "gridArcade_highScore")
        store.updateGauntletBest(avg: 500)
        store.updateGauntletBest(avg: 450)
        store.updateGauntletBest(avg: 480)

        XCTAssertEqual(store.highScore(for: .gridArcade), 12)
        XCTAssertNil(store.highScore(for: .flash))
        XCTAssertEqual(store.gauntletBestAvg, 450)
        XCTAssertEqual(store.gauntletHistory, [500, 450, 480])
    }

    func testGauntletHistoryKeepsMostRecentTen() {
        for i in 1...12 {
            store.updateGauntletBest(avg: Double(100 + i))
        }

        XCTAssertEqual(store.gauntletHistory.count, 10)
        XCTAssertEqual(store.gauntletHistory.first, 103)
        XCTAssertEqual(store.gauntletHistory.last, 112)
    }
}
