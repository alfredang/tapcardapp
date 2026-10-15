import XCTest

final class TapcardFeatureTests: XCTestCase {
    @MainActor
    func testHomeHasCenteredCardAndSeparateLinkedInQR() {
        let app = XCUIApplication()
        app.launchEnvironment["TAPCARD_DEMO"] = "1"
        app.launch()
        XCTAssertTrue(app.staticTexts["Jordan Avery"].firstMatch.waitForExistence(timeout:10))
        capture(app, name: "Centered profile card")
        app.swipeUp()
        let linkedin = app.buttons["LinkedIn"].firstMatch
        XCTAssertTrue(linkedin.waitForExistence(timeout:5))
        linkedin.tap()
        XCTAssertTrue(app.staticTexts["Scan to connect on LinkedIn"].waitForExistence(timeout:5))
        app.buttons["WhatsApp"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Scan to chat on WhatsApp"].waitForExistence(timeout:5))
        app.buttons["Card link"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Scan to open my card"].waitForExistence(timeout:5))
        app.buttons["WhatsApp"].firstMatch.tap()
        capture(app, name: "Card and QR")
    }
    @MainActor
    func testSettingsDesignAndSharingPreferences() {
        let app = XCUIApplication()
        app.launchEnvironment["TAPCARD_DEMO"] = "1"
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["WhatsApp chats with"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["+65 9123 4567"].exists)
        capture(app, name: "Settings sharing")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Card design'")).firstMatch.tap()
        let rose = app.buttons["Rose colour"]
        XCTAssertTrue(rose.waitForExistence(timeout:5))
        rose.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: rose)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 3), .completed)
        capture(app, name: "Settings card design")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'QR code opens'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["LinkedIn"].firstMatch.waitForExistence(timeout:5))
        app.buttons["LinkedIn"].firstMatch.tap()
        app.tabBars.buttons["Cards"].tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Scan to connect on LinkedIn"].waitForExistence(timeout:5))
    }

    @MainActor
    func testGoogleLoginVisibleInConfiguredBuild() {
        let app = XCUIApplication()
        app.launchEnvironment["TAPCARD_DEMO_AUTH"] = "logIn"
        app.launch()
        XCTAssertTrue(app.buttons["Continue with Google"].waitForExistence(timeout:10))
        capture(app, name: "Google login")
    }
    @MainActor
    func testDesignGalleryAndProfilePhotoPicker() {
        let app = XCUIApplication()
        app.launchEnvironment["TAPCARD_DEMO"] = "1"
        app.launch()
        for _ in 0..<4 {
            if app.buttons["Edit"].isHittable { break }
            app.swipeUp()
        }
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.buttons["Change profile photo"].waitForExistence(timeout:5))
        app.buttons["Change profile photo"].tap()
        XCTAssertTrue(app.buttons["Choose from Photos"].waitForExistence(timeout:5))
        app.buttons["Choose from Photos"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout:5))
        if app.buttons["Close"].exists { app.buttons["Close"].tap() }
        for _ in 0..<3 {
            if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        }
        XCTAssertFalse(app.buttons["Cancel"].exists)
        let designs = ["Executive Lines, Corporate design", "Orbit, Modern design", "Editorial, Minimalist design", "Blueprint, Dark design", "Confetti, Creative design", "Gold Frame, Luxury design", "Ocean Waves, Ocean design", "Alpine, Forest design", "Golden Hour, Sunset design", "Petal Rings, Rose design", "Prism, Indigo design", "Flow, Teal design", "Sunburst, Amber design", "Velocity, Crimson design", "Soft Bloom, Lavender design", "Constellation, Midnight design", "Cloudscape, Sky design", "Dot Studio, Mint design", "Ribbon, Peach design", "Facet, Graphite design"]
        for name in designs {
            let button = app.buttons[name]
            for _ in 0..<14 {
                if button.exists && button.isHittable {
                    let top = app.navigationBars.firstMatch.frame.maxY
                    if button.frame.maxY > app.frame.maxY - 60 { app.swipeUp() }
                    else if button.frame.minY < top + 20 { app.swipeDown() }
                    else { break }
                } else { app.swipeUp() }
            }
            guard button.isHittable else { XCTFail("Design unavailable: " + name); return }
            button.tap()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: button)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 3), .completed, name)
            if name.hasPrefix("Orbit") || name.hasPrefix("Flow") || name.hasPrefix("Facet") {
                capture(app, name: "Design gallery " + name)
            }
        }
        for _ in 0..<18 {
            if app.buttons["Change profile photo"].isHittable { break }
            app.swipeDown()
        }
        capture(app, name: "Selected Facet card")
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.switches["Log in with Face ID"].waitForExistence(timeout:5))
    }

    @MainActor
    func testGoogleConsentCancellationKeepsLoginUsable() {
        let app = XCUIApplication()
        app.launchEnvironment["TAPCARD_DEMO_AUTH"] = "logIn"
        app.launch()
        XCTAssertTrue(app.buttons["Continue with Google"].waitForExistence(timeout:10))
        app.buttons["Continue with Google"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let safari = XCUIApplication(bundleIdentifier: "com.apple.SafariViewService")
        if safari.buttons["Cancel"].waitForExistence(timeout:5) {
            safari.buttons["Cancel"].tap()
        } else if springboard.alerts.buttons["Cancel"].exists {
            springboard.alerts.buttons["Cancel"].tap()
        } else if app.alerts.buttons["Cancel"].exists {
            app.alerts.buttons["Cancel"].tap()
        }
        let enabled = NSPredicate(format: "enabled == true")
        expectation(for: enabled, evaluatedWith: app.buttons["Continue with Google"])
        waitForExpectations(timeout:10)
        XCTAssertTrue(app.buttons["Continue with Google"].isEnabled)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        // Keep screenshots recoverable even if Xcode's result-bundle transfer stalls.
        let path = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name + ".png")
        do {
            try screenshot.pngRepresentation.write(to: path)
            print("QA_SCREENSHOT_PATH: " + path.path)
        } catch { XCTFail("Couldn't save screenshot: " + error.localizedDescription) }
    }

}
