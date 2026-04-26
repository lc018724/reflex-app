import XCTest

final class WalkthroughUITests: XCTestCase {
    private let screenshotNames: [(name: String, launchArguments: [String])] = [
        ("02-flash", ["REFLEX_START_MODE", "FLASH"]),
        ("03-catch", ["REFLEX_START_MODE", "CATCH"]),
        ("04-find", ["REFLEX_START_MODE", "FIND"]),
        ("05-color", ["REFLEX_START_MODE", "COLOR"]),
        ("06-stroop", ["REFLEX_START_MODE", "STROOP"]),
        ("07-decode", ["REFLEX_START_MODE", "DECODE"]),
        ("08-odd-one", ["REFLEX_START_MODE", "ODD ONE"]),
        ("09-mirror", ["REFLEX_START_MODE", "MIRROR"]),
        ("10-control", ["REFLEX_START_MODE", "CONTROL"]),
        ("11-math", ["REFLEX_START_MODE", "MATH"]),
        ("12-dark", ["REFLEX_START_MODE", "DARK"]),
        ("13-sequence", ["REFLEX_START_MODE", "SEQUENCE"]),
        ("14-n-back", ["REFLEX_START_MODE", "N-BACK"]),
        ("15-edge", ["REFLEX_START_MODE", "EDGE"]),
        ("16-double", ["REFLEX_START_MODE", "DOUBLE"]),
        ("17-digit", ["REFLEX_START_MODE", "DIGIT"]),
        ("18-simon", ["REFLEX_START_MODE", "SIMON"]),
        ("19-sort", ["REFLEX_START_MODE", "SORT"]),
        ("20-rhythm", ["REFLEX_START_MODE", "RHYTHM"]),
        ("21-dual", ["REFLEX_START_MODE", "DUAL"]),
        ("22-gauntlet", ["REFLEX_START_GAUNTLET"]),
        ("23-drop", ["REFLEX_START_MODE", "DROP"]),
        ("24-whack", ["REFLEX_START_MODE", "WHACK"]),
        ("25-chain", ["REFLEX_START_MODE", "CHAIN"]),
        ("26-grid", ["REFLEX_START_MODE", "GRID"]),
        ("27-avoid", ["REFLEX_START_MODE", "AVOID"]),
        ("28-memory", ["REFLEX_START_MODE", "MEMORY"])
    ]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testOpenEveryModeAndCaptureScreenshots() throws {
        try FileManager.default.createDirectory(at: screenshotDirectory, withIntermediateDirectories: true)

        for item in screenshotNames {
            let app = launchApp(arguments: item.launchArguments)
            waitForModeContent(in: app)
            startCognitiveModeIfNeeded(arguments: item.launchArguments, in: app)
            try saveScreenshot(named: item.name)
            app.terminate()
        }
    }

    private func launchApp(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["REFLEX_SKIP_ONBOARDING"] + arguments
        app.launch()
        return app
    }

    private func waitForModeContent(in app: XCUIApplication) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
    }

    private func startCognitiveModeIfNeeded(arguments: [String], in app: XCUIApplication) {
        guard arguments.first == "REFLEX_START_MODE",
              let rawValue = arguments.last,
              !arcadeRawValues.contains(rawValue) else {
            return
        }

        let startButton = app.buttons["START"].firstMatch
        if startButton.waitForExistence(timeout: 2) {
            startButton.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(3.2))
        }
    }

    private var arcadeRawValues: Set<String> {
        ["DROP", "WHACK", "CHAIN", "GRID", "AVOID", "MEMORY"]
    }

    private func saveScreenshot(named name: String) throws {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        let url = screenshotDirectory.appendingPathComponent("\(name).png")
        try data.write(to: url, options: .atomic)
    }

    private var screenshotDirectory: URL {
        if let path = ProcessInfo.processInfo.environment["REFLEX_SCREENSHOT_DIR"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 {
            url.deleteLastPathComponent()
        }
        return url.appendingPathComponent("screenshots", isDirectory: true)
    }
}
