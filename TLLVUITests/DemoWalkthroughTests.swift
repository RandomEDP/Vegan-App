import XCTest

/// Walks through the app like a person would, for the demo video.
/// The "Record demo video" GitHub workflow records the simulator while this runs,
/// and saves a full-resolution screenshot at each step (`shot(_:)`), which is
/// what the smooth showcase video is edited from.
final class DemoWalkthroughTests: XCTestCase {
    private var app: XCUIApplication!
    private var shotIndex = 0

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
        wait(4) // let photos load
        shot("discover")
        let home = app.scrollViews.firstMatch
        home.swipeUp(velocity: .slow)
        wait(2)
        shot("discover-scroll", transition: "scroll")
        home.swipeUp(velocity: .slow)
        wait(2)
        shot("discover-scroll", transition: "scroll")
        home.swipeDown(velocity: .fast)
        home.swipeDown(velocity: .fast)
        home.swipeDown(velocity: .fast)
        wait(1.5)

        // A restaurant page
        if tapFirst(containing: "Facing Heaven") {
            wait(3.5)
            shot("restaurant", transition: "push")
            app.swipeUp(velocity: .slow)
            wait(2)
            shot("restaurant-scroll", transition: "scroll")
            app.swipeUp(velocity: .slow)
            wait(2)
            shot("restaurant-scroll", transition: "scroll")
            app.swipeUp(velocity: .slow)
            wait(2)
            shot("restaurant-scroll", transition: "scroll")
            goBack()
        }

        // Explore: map, then list and search
        app.tabBars.buttons["Explore"].tap()
        wait(5)
        shot("map", transition: "fade")
        let list = segment(1)
        if list.waitForExistence(timeout: 5) {
            list.tap()
            wait(2.5)
            shot("list", transition: "fade")
            let search = app.searchFields.firstMatch
            if search.waitForExistence(timeout: 5) {
                search.tap()
                search.typeText("pizza")
                wait(3)
                shot("search", transition: "fade")
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
            shot("filters", transition: "sheet")
            let show = app.navigationBars["Filters"].buttons.matching(NSPredicate(format: "label BEGINSWITH 'Show'")).firstMatch
            if show.exists { show.tap() } else { app.swipeDown(velocity: .fast) }
            wait(1.5)
        }

        // Guides
        app.tabBars.buttons["Guides"].tap()
        wait(3)
        shot("guides", transition: "fade")
        if tapFirst(containing: "Favourite Restaurants") {
            wait(3)
            shot("guide", transition: "push")
            app.swipeUp(velocity: .slow)
            wait(2)
            shot("guide-scroll", transition: "scroll")
            goBack()
        }
        let travel = segment(1)
        if travel.exists {
            travel.tap()
            wait(3)
            shot("travel", transition: "fade")
            app.swipeDown(velocity: .fast)
            wait(1)
            if segment(0).exists { segment(0).tap() }
            wait(1)
        }

        // Perks
        app.tabBars.buttons["Perks"].tap()
        wait(3.5)
        shot("perks", transition: "fade")
        if tapFirst(containing: "Amrutha") {
            wait(3)
            shot("perk", transition: "push")
            goBack()
        }

        // Saved
        app.tabBars.buttons["Saved"].tap()
        wait(3)
        shot("saved", transition: "fade")
        if tapFirst(containing: "Date night") {
            wait(3)
            shot("saved-list", transition: "push")
            goBack()
        }

        // Back home
        app.tabBars.buttons["Discover"].tap()
        wait(2)
        shot("end", transition: "fade")
    }

    // MARK: Helpers

    /// Saves a full-resolution screenshot. `transition` tells the video editor
    /// how to move to this screen: fade (tab switch), push, scroll or sheet.
    private func shot(_ name: String, transition: String = "fade") {
        shotIndex += 1
        let screenshot = XCUIScreen.main.screenshot()
        let filename = String(format: "%02d-%@-%@.png", shotIndex, transition, name)
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = filename
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SHOT_DIR"], !dir.isEmpty {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent(filename))
        }
    }

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
