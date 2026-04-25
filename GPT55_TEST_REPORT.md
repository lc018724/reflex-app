# Reflex Test Report

## Phase 1 results

Status: completed.

Initial verification:
- `rg -n "import XCTest" .` found no XCTest imports in app source. The only match was the directive file.

Tests added:
- `ModelsTests.testModeCatalogHasTwentyCognitiveModesAndSixArcadeModes`: pass.
- `ModelsTests.testModeRawValuesAndIdentifiersAreUnique`: pass.
- `ModelsTests.testModeMetadataIsPresentForEveryMode`: pass.
- `ModelsTests.testTrialCountsMatchModeFamilies`: pass.
- `ModelsTests.testTierAssignmentsKeepArcadeModesOutOfCognitiveProgress`: pass.
- `ModelsTests.testNamedColorRandomHonorsExclusionsAndRequestedCount`: pass.
- `ModelsTests.testValueTypeEqualityForSupportingModels`: pass.
- `TestEngineTests.testStartSessionShowsInstructionAndResetReturnsIdle`: pass.
- `TestEngineTests.testStimulusTimingUsesResetMoment`: pass.
- `TestEngineTests.testSessionSummaryAveragesOnlyValidTapResults`: pass.
- `TestEngineTests.testRapidTapProducesNonNegativeResult`: pass.
- `TestEngineTests.testCorrectNoTapTrialsCompleteNoGoSession`: fail.
- `TestStoreTests.testBestScorePersistsAndOnlyImproves`: pass.
- `TestStoreTests.testInvalidBestScoreDoesNotBlockFutureValidBest`: fail.
- `TestStoreTests.testHistoryRoundTripIsModeScopedAndTrimmedToThirty`: pass.
- `TestStoreTests.testResetAllClearsScoresHistoryAndCounters`: pass.
- `TestStoreTests.testArcadeHighScoresAndGauntletBestRoundTrip`: pass.
- `TestStoreTests.testGauntletHistoryKeepsMostRecentTen`: pass.

Run result:
- Command: `xcodebuild test -scheme Reflex -destination 'platform=iOS Simulator,name=iPhone 17'`
- Result: build succeeded, test action failed because 2 of 18 tests failed.
- Pass count: 16.
- Fail count: 2.

Findings:
- Correct no-tap trials do not count toward session progress. `TestEngine.handleNoTap()` calls `advanceTrial(ms: nil)` for correct no-go and non-match N-Back stimuli without incrementing `currentTrial`; repeated correct no-tap trials never finish a session. Source: `Sources/Reflex/TestEngine.swift:400`.
- Invalid best-score inputs can block future valid best scores. `TestStore.updateBest(ms:for:)` stores negative values when no best exists, while `bestMS(for:)` hides them; later positive values are not accepted because they are not lower than the stored negative value. Source: `Sources/Reflex/TestStore.swift:20`.
