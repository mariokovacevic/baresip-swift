import XCTest

@MainActor
final class RegistrationCallUITests: XCTestCase {
    private let app = XCUIApplication()

    func testTLSRegistrationPinningAndCall() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        guard let host = env["BSK_UITEST_HOST"], let ca = env["BSK_UITEST_CA_PEM"] else {
            throw XCTSkip("BSK_UITEST_HOST and BSK_UITEST_CA_PEM are not set")
        }
        let port = env["BSK_UITEST_PORT"] ?? "5081"
        let peer = env["BSK_UITEST_PEER"] ?? "sip:bob@\(host):5070"

        app.launchEnvironment = ["BSK_UITEST": "1", "BSK_UITEST_CA_PEM": ca]
        app.launch()

        openAccount()
        type(host, into: field("account.domain"))
        type(port, into: field("account.port"))
        type("alice", into: field("account.username"))
        type("secret", into: passwordField())
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

        let destination = field("call.destination")
        type(peer, into: destination)
        app.buttons["call.audio"].tap()
        let state = app.staticTexts["call.state"]
        XCTAssertTrue(state.waitForExistence(timeout: 15), "call did not start")
        let running = NSPredicate(format: "value CONTAINS 'streamsRunning'")
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
        dismissSystemPrompts()
        if !link.isHittable {
            XCTFail("account.link not hittable in:\n\(app.debugDescription)")
            return
        }
        link.tap()
        XCTAssertTrue(field("account.domain").waitForExistence(timeout: 5))
    }

    private func field(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func passwordField() -> XCUIElement {
        let byIdentifier = field("account.password")
        return byIdentifier.exists ? byIdentifier : app.secureTextFields.firstMatch
    }

    private func pinsField() -> XCUIElement {
        field("account.pins")
    }

    private func type(_ text: String, into field: XCUIElement) {
        dismissSystemPrompts()
        scrollTo(field)
        guard field.exists else {
            XCTFail("\(field) not found in:\n\(app.debugDescription)")
            return
        }
        field.tap()
        field.typeText(text)
    }

    private func scrollTo(_ element: XCUIElement) {
        let maximumSteps = 30
        var steps = 0
        while !element.exists, steps < maximumSteps {
            drag(towardsTop: true)
            steps += 1
        }
        steps = 0
        while !(element.exists && element.isHittable), steps < maximumSteps {
            drag(towardsTop: false)
            steps += 1
        }
    }

    private func drag(towardsTop: Bool) {
        let upper = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        let lower = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        if towardsTop {
            upper.press(forDuration: 0.05, thenDragTo: lower)
        } else {
            lower.press(forDuration: 0.05, thenDragTo: upper)
        }
    }

    private func save() {
        let button = app.buttons["account.save"]
        scrollTo(button)
        XCTAssertTrue(button.isEnabled, "save button disabled")
        button.tap()
        dismissPasswordSavePrompt()
    }

    private func dismissPasswordSavePrompt() {
        let notNow = app.buttons["Not Now"]
        if notNow.waitForExistence(timeout: 3) {
            notNow.tap()
        }
    }

    private func dismissSystemPrompts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for owner in [app, springboard] {
            for label in ["Not Now", "Allow", "OK"] where owner.buttons[label].exists {
                owner.buttons[label].tap()
            }
        }
    }

    private func waitForRegistration(containing text: String, timeout: TimeInterval) {
        let label = app.staticTexts["registration.state"]
        XCTAssertTrue(label.waitForExistence(timeout: 10))
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        expectation(for: predicate, evaluatedWith: label)
        waitForExpectations(timeout: timeout)
    }
}
