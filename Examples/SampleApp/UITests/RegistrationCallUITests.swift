import XCTest

final class RegistrationCallUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTLSRegistrationPinningAndCall() throws {
        let env = ProcessInfo.processInfo.environment
        guard let host = env["BSK_UITEST_HOST"], let ca = env["BSK_UITEST_CA_PEM"] else {
            throw XCTSkip("BSK_UITEST_HOST and BSK_UITEST_CA_PEM are not set")
        }
        let port = env["BSK_UITEST_PORT"] ?? "5081"
        let peer = env["BSK_UITEST_PEER"] ?? "sip:bob@\(host):5070"

        app = XCUIApplication()
        app.launchEnvironment = ["BSK_UITEST": "1", "BSK_UITEST_CA_PEM": ca]
        app.launch()

        openAccount()
        type(host, into: app.textFields["account.domain"])
        type(port, into: app.textFields["account.port"])
        type("alice", into: app.textFields["account.username"])
        type("secret", into: app.secureTextFields["account.password"])
        save()
        waitForRegistration(containing: "registered", timeout: 30)

        openAccount()
        type("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", into: pinsField())
        save()
        waitForRegistration(containing: "failed", timeout: 30)

        openAccount()
        let clear = app.buttons["account.pins.clear"]
        scrollTo(clear)
        clear.tap()
        save()
        waitForRegistration(containing: "registered", timeout: 30)

        let destination = app.textFields["call.destination"]
        type(peer, into: destination)
        app.buttons["call.audio"].tap()
        let state = app.staticTexts["call.state"]
        XCTAssertTrue(state.waitForExistence(timeout: 15), "call did not start")
        let running = NSPredicate(format: "label CONTAINS 'streamsRunning'")
        expectation(for: running, evaluatedWith: state)
        waitForExpectations(timeout: 20)
        sleep(3)
        app.buttons["call.hangup"].tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: state)
        waitForExpectations(timeout: 15)
    }

    private func openAccount() {
        let link = app.buttons["account.link"]
        XCTAssertTrue(link.waitForExistence(timeout: 10))
        link.tap()
        XCTAssertTrue(app.textFields["account.domain"].waitForExistence(timeout: 5))
    }

    private func pinsField() -> XCUIElement {
        let field = app.textFields["account.pins"]
        if field.exists {
            return field
        }
        return app.textViews["account.pins"]
    }

    private func type(_ text: String, into field: XCUIElement) {
        scrollTo(field)
        field.tap()
        field.typeText(text)
    }

    private func scrollTo(_ element: XCUIElement) {
        var attempts = 0
        while !element.isHittable && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
    }

    private func save() {
        let button = app.buttons["account.save"]
        scrollTo(button)
        XCTAssertTrue(button.isEnabled, "save button disabled")
        button.tap()
    }

    private func waitForRegistration(containing text: String, timeout: TimeInterval) {
        let label = app.staticTexts["registration.state"]
        XCTAssertTrue(label.waitForExistence(timeout: 10))
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        expectation(for: predicate, evaluatedWith: label)
        waitForExpectations(timeout: timeout)
    }
}
