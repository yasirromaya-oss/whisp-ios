import XCTest

final class DXWhispUITests: XCTestCase {

    // MARK: - Dark Mode Screenshots (01–05)

    @MainActor
    func testScreenshots() {
        captureScreenshots(startIndex: 1)
    }

    // MARK: - Shared Flow

    @MainActor
    private func captureScreenshots(startIndex: Int) {
        continueAfterFailure = false
        let app = XCUIApplication()
        addTeardownBlock { @MainActor in app.terminate() }

        setupSnapshot(app, waitForAnimations: true)
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-screenshotMode", "YES",
            "-darkMode",
        ]
        app.launch()

        // 1. Notes List — populated with mock data
        XCTAssertTrue(waitForTabButton("Notes", in: app), "Notes tab not found")
        waitForUI(in: app)
        snapshot(String(format: "%02d_NotesList", startIndex))

        // 2. Note Detail — Insights (top of detail)
        let firstNoteCard = app.buttons.matching(identifier: "note_card").firstMatch
        XCTAssertTrue(firstNoteCard.waitForExistence(timeout: 5))
        firstNoteCard.tap()
        waitForUI(in: app)
        snapshot(String(format: "%02d_NoteDetail_Insights", startIndex + 1))

        // 3. Note Detail — Action Items (scrolled down)
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            waitForUI(in: app)
        }
        snapshot(String(format: "%02d_NoteDetail_ActionItems", startIndex + 2))

        // 4. Dismiss detail sheet
        dismissSheet(in: app)

        // 5. Switch to Record tab and start recording
        XCTAssertTrue(tapTabButton("Record", in: app), "Could not tap Record tab")
        waitForUI(in: app)

        let recordButton = app.buttons["record_button"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5), "Record button not found")
        recordButton.tap()
        waitForUI(in: app)
        snapshot(String(format: "%02d_Recording", startIndex + 3))

        // Stop recording before navigating away
        recordButton.tap()
        waitForUI(in: app)

        // 6. Settings tab
        XCTAssertTrue(tapTabButton("Settings", in: app), "Could not tap Settings tab")
        waitForUI(in: app)
        snapshot(String(format: "%02d_Settings", startIndex + 4))
    }

    // MARK: - Helpers

    /// Waits for UI to settle after a transition (animations, layout).
    @MainActor
    private func waitForUI(in app: XCUIApplication) {
        let settledExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: app.windows.firstMatch
        )
        _ = XCTWaiter.wait(for: [settledExpectation], timeout: 3)
    }

    /// Dismisses the currently presented sheet.
    @MainActor
    private func dismissSheet(in app: XCUIApplication) {
        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
        } else {
            app.swipeDown()
        }
        // Wait for sheet dismissal animation
        let sheetGone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: doneButton
        )
        _ = XCTWaiter.wait(for: [sheetGone], timeout: 3)
    }

    /// Waits for a tab button to exist.
    @MainActor
    private func waitForTabButton(_ label: String, in app: XCUIApplication) -> Bool {
        // iPhone bottom tab bar
        let tabBarButton = app.tabBars.buttons[label]
        if tabBarButton.waitForExistence(timeout: 5) { return true }
        // iPad floating tab bar — use firstMatch to handle duplicate nested elements
        let predicate = NSPredicate(format: "label == %@", label)
        let fallback = app.buttons.matching(predicate).firstMatch
        return fallback.waitForExistence(timeout: 5)
    }

    /// Finds and taps a tab button, handling iPadOS 26 floating tab bar.
    ///
    /// iPadOS 26 renders `_UIFloatingTabBarItemCell` containing `_UIFloatingTabBarItemView`,
    /// both exposed as buttons with the same label. Using `firstMatch` + coordinate tap
    /// works around the "multiple matching elements" and automation type mismatch errors.
    @MainActor
    @discardableResult
    private func tapTabButton(_ label: String, in app: XCUIApplication) -> Bool {
        // iPhone-style bottom tab bar
        let tabBarButton = app.tabBars.buttons[label]
        if tabBarButton.waitForExistence(timeout: 2) {
            tabBarButton.tap()
            return true
        }
        // iPad floating tab bar — use predicate + firstMatch to avoid
        // "Multiple matching elements" error from nested Cell/View pair
        let predicate = NSPredicate(format: "label == %@", label)
        let button = app.buttons.matching(predicate).firstMatch
        if button.waitForExistence(timeout: 3) {
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            return true
        }
        return false
    }
}
