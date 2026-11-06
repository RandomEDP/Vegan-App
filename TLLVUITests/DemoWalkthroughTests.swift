import XCTest

/// Walks through the app like a person would, for the demo video.
/// Run with the "Record demo video" GitHub workflow, which records the simulator.
final class DemoWalkthroughTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-TLLVDemoMode"]
        app.launch()
        addUIInterruptionMonitor(withDescription: "System alerts") { alert in
            for label in ["Allow While Using App", "Allow Once", "OK", "Allow"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
    }

    func testDemoWalkthrough() throws {
        // Discover
        _ = app.staticTexts["Restaurant Reviews"].waitForExistence(timeout: 20)
        wait(3)
        let carousel = app.scrollViews.firstMatch
        carousel.swipeUp(velocity: .slow)
        wait(2)
        carousel.swipeUp(velocity: .slow)
        wait(2)
        carousel.swipeDown(velocity: .fast)
        carousel.swipeDown(velocity: .fast)
        wait(1.5)

        // A restaurant page
        if tapFirst(containing: "Facing Heaven") {
            wait(3)
            app.swipeLeft()   // photo gallery
            wait(1.5)
            app.swipeUp(velocity: .slow)
            wait(2)
            app.swipeUp(velocity: .slow)
            wait(2)
            app.swipeUp(velocity: .slow)
            wait(2)
            goBack()
        }

        // Explore: map, then list and search
        app.tabBars.buttons["Explore"].tap()
        wait(4)
        let list = segment(1)
        if list.waitForExistence(timeout: 5) {
            list.tap()
            wait(2.5)
            let search = app.searchFields.firstMatch
            if search.waitForExistence(timeout: 5) {
                search.tap()
                search.typeText("pizza")
                wait(3)
                if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
                wait(1)
            }
            if segment(0).exists { segment(0).tap() }
            wait(2)
        }
        let filters = app.navigationBars.buttons["Filters"]
        if filters.exists {
            filters.tap()
            wait(3)
            app.swipeUp(velocity: .slow)
            wait(1.5)
            let show = app.navigationBars["Filters"].buttons.matching(NSPredicate(format: "label BEGINSWITH 'Show'")).firstMatch
            if show.exists { show.tap() } else { app.swipeDown(velocity: .fast) }
            wait(1.5)
        }

        // Guides
        app.tabBars.buttons["Guides"].tap()
        wait(2.5)
        if tapFirst(containing: "Favourite Restaurants") {
            wait(2.5)
            app.swipeUp(velocity: .slow)
            wait(2)
            goBack()
        }
        let travel = segment(1)
        if travel.exists {
            travel.tap()
            wait(2.5)
            app.swipeUp(velocity: .slow)
            wait(2)
            app.swipeDown(velocity: .fast)
            app.swipeDown(velocity: .fast)
            wait(1)
            if segment(0).exists { segment(0).tap() }
            wait(1)
        }

        // Perks
        app.tabBars.buttons["Perks"].tap()
        wait(3)
        if tapFirst(containing: "Amrutha") {
            wait(3)
            goBack()
        }

        // Saved
        app.tabBars.buttons["Saved"].tap()
        wait(2.5)
        if tapFirst(containing: "Date night") {
            wait(3)
            goBack()
        }

        // Back home
        app.tabBars.buttons["Discover"].tap()
        wait(3)
    }

    // MARK: Helpers

    private func wait(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    @discardableResult
    private func tapFirst(containing text: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        for query in [app.buttons, app.cells, app.staticTexts] {
            let element = query.matching(predicate).firstMatch
            if element.waitForExistence(timeout: 3), element.isHittable {
                element.tap()
                return true
            }
        }
        return false
    }

    /// Segment buttons in the first segmented control. SwiftUI labels them from
    /// their SF Symbols ("Show Map"), so match by position instead of by name.
    private func segment(_ index: Int) -> XCUIElement {
        app.segmentedControls.firstMatch.buttons.element(boundBy: index)
    }

    private func goBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists { back.tap() }
        wait(1.5)
    }
}
