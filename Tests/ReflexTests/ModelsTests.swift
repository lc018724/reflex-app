import XCTest
import SwiftUI
@testable import Reflex

final class ModelsTests: XCTestCase {
    func testModeCatalogHasTwentyCognitiveModesAndSixArcadeModes() {
        let cognitive = TestMode.allCases.filter { !$0.isArcade }
        let arcade = TestMode.allCases.filter(\.isArcade)

        XCTAssertEqual(cognitive.count, 20)
        XCTAssertEqual(arcade.count, 6)
        XCTAssertEqual(TestMode.allCases.count, 26)
    }

    func testModeRawValuesAndIdentifiersAreUnique() {
        let rawValues = TestMode.allCases.map(\.rawValue)
        let ids = TestMode.allCases.map(\.id)

        XCTAssertEqual(Set(rawValues).count, TestMode.allCases.count)
        XCTAssertEqual(Set(ids).count, TestMode.allCases.count)
        XCTAssertEqual(rawValues, ids)
    }

    func testModeMetadataIsPresentForEveryMode() {
        for mode in TestMode.allCases {
            XCTAssertFalse(mode.title.isEmpty, "\(mode) title")
            XCTAssertFalse(mode.subtitle.isEmpty, "\(mode) subtitle")
            XCTAssertFalse(mode.instruction.isEmpty, "\(mode) instruction")
        }
    }

    func testTrialCountsMatchModeFamilies() {
        XCTAssertEqual(TestMode.sequence.trialCount, 6)
        XCTAssertEqual(TestMode.nBack.trialCount, 6)
        XCTAssertEqual(TestMode.doubleFlash.trialCount, 4)

        let defaultFiveTrialModes = TestMode.allCases.filter {
            !$0.isArcade && ![.sequence, .nBack, .doubleFlash].contains($0)
        }
        XCTAssertFalse(defaultFiveTrialModes.isEmpty)
        for mode in defaultFiveTrialModes {
            XCTAssertEqual(mode.trialCount, 5, "\(mode) trial count")
        }
    }

    func testTierAssignmentsKeepArcadeModesOutOfCognitiveProgress() {
        for mode in TestMode.allCases {
            if mode.isArcade {
                XCTAssertEqual(mode.tier, 0, "\(mode) arcade tier")
            } else {
                XCTAssertTrue((1...5).contains(mode.tier), "\(mode) cognitive tier")
            }
        }
    }

    func testNamedColorRandomHonorsExclusionsAndRequestedCount() {
        let excluded = Array(NamedColor.all.prefix(2))
        let colors = NamedColor.random(3, excluding: excluded)

        XCTAssertEqual(colors.count, 3)
        XCTAssertTrue(colors.allSatisfy { !excluded.contains($0) })
        XCTAssertEqual(Set(colors.map(\.name)).count, colors.count)
    }

    func testValueTypeEqualityForSupportingModels() {
        XCTAssertEqual(NamedColor(name: "GOLD", color: .yellow), NamedColor(name: "GOLD", color: .yellow))
        XCTAssertNotEqual(NamedColor(name: "GOLD", color: .yellow), NamedColor(name: "BLUE", color: .blue))
        XCTAssertEqual(LRDir.left, .left)
        XCTAssertNotEqual(LRDir.left, .right)
        XCTAssertEqual(OddStyle.symbol, .symbol)
    }
}
