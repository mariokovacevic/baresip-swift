import XCTest

/// Takes screenshots of the app's screens with demo doors, activity and messages, a ring from
/// a door, a call to it and the door's messages during the call. CI runs it after the
/// registration test, with a registrar, a door that rings and writes
/// (`Tools/SampleScreenshots/ring.py`) and a peer that answers.
@MainActor
final class ScreenshotTests: XCTestCase {
    private let app = XCUIApplication()
    private var folder = URL(fileURLWithPath: NSTemporaryDirectory())
    private var pause: TimeInterval = 0

    func testScreens() throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["BSK_SCREENSHOTS"], let host = env["BSK_UITEST_HOST"],
              let ca = env["BSK_UITEST_CA_PEM"] else {
            throw XCTSkip("BSK_SCREENSHOTS, BSK_UITEST_HOST and BSK_UITEST_CA_PEM are not set")
        }
        folder = URL(fileURLWithPath: path)
        pause = TimeInterval(env["BSK_SCREENSHOT_PAUSE"] ?? "") ?? 0
        let port = env["BSK_UITEST_PORT"] ?? "5082"

        app.launchEnvironment = ["BSK_UITEST": "1", "BSK_UITEST_CA_PEM": ca]
        app.launch()
        dismissSystemPrompts()
        XCTAssertTrue(app.staticTexts["Connect your intercom"].waitForExistence(timeout: 20))
        shoot("01-setup")
        app.terminate()

        app.launchEnvironment = [
            "BSK_UITEST": "1", "BSK_UITEST_CA_PEM": ca, "BSK_DEMO": "1",
            "BSK_DEMO_HOST": host, "BSK_DEMO_PORT": port,
        ]
        app.launch()
        dismissSystemPrompts()
        let reachable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Reachable'")).firstMatch
        _ = reachable.waitForExistence(timeout: 30)
        shoot("02-doors")

        openTab("Activity")
        shoot("03-activity")
        openTab("Keypad")
        for key in ["1", "0", "1"] {
            app.buttons[key].firstMatch.tap()
        }
        scrollTo(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'Caretaker'")).firstMatch)
        shoot("04-keypad")
        openTab("Messages")
        shoot("05-messages")
        if open(app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'reception'")).firstMatch) {
            shoot("06-conversation")
            goBack()
        }

        openTab("Settings")
        shoot("07-settings")
        if open(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Front door'")).firstMatch) {
            shoot("08-door")
            goBack()
        }
        if open(app.buttons["account.link"]) {
            shoot("09-account")
            goBack()
        }
        let diagnostics = app.buttons["engine.link"]
        scrollTo(diagnostics)
        if open(diagnostics) {
            shoot("10-diagnostics")
            goBack()
        }

        ring()
        callFrontDoor()
    }

    private func ring() {
        FileManager.default.createFile(atPath: folder.appendingPathComponent("ring.trigger").path, contents: Data())
        let answer = app.buttons["incoming.answer"]
        guard answer.waitForExistence(timeout: 30) else {
            XCTFail("the door's ring did not arrive in:\n\(app.debugDescription)")
            return
        }
        sleep(2)
        shoot("11-ring")
        let reject = app.buttons["incoming.reject"]
        guard reject.exists else { return }
        reject.tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: answer)
        waitForExpectations(timeout: 15)
    }

    private func callFrontDoor() {
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        openTab("Doors")
        let look = app.buttons.matching(identifier: "door.look").firstMatch
        guard look.waitForExistence(timeout: 10) else {
            XCTFail("the Front door card is missing in:\n\(app.debugDescription)")
            return
        }
        look.tap()
        let state = app.staticTexts["call.state"]
        guard state.waitForExistence(timeout: 20) else {
            XCTFail("the call did not start in:\n\(app.debugDescription)")
            return
        }
        let running = NSPredicate(format: "value CONTAINS 'streamsRunning'")
        expectation(for: running, evaluatedWith: state)
        waitForExpectations(timeout: 20)
        sleep(3)
        dismissSystemPrompts()
        shoot("12-call")
        if open(app.buttons["call.more"]) {
            sleep(1)
            shoot("13-call-more")
            app.buttons["Done"].firstMatch.tap()
        }
        messageDuringTheCall()
        let hangUp = app.buttons["call.hangup"]
        if hangUp.waitForExistence(timeout: 5) {
            hangUp.tap()
        }
    }

    private func messageDuringTheCall() {
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        FileManager.default.createFile(atPath: folder.appendingPathComponent("message.trigger").path,
                                       contents: Data())
        let caption = app.descendants(matching: .any)["call.caption"].firstMatch
        guard caption.waitForExistence(timeout: 20) else {
            XCTFail("no caption of the door's message in:\n\(app.debugDescription)")
            return
        }
        sleep(2)
        shoot("14-call-caption")
        guard open(app.buttons["call.chat"]) else {
            XCTFail("no chat button on the call screen")
            return
        }
        sleep(1)
        shoot("15-call-chat")
        let done = app.buttons["chat.done"]
        if done.waitForExistence(timeout: 5) {
            done.tap()
        }
        RunLoop.current.run(until: Date().addingTimeInterval(1))
    }

    private func shoot(_ name: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try? screenshot.pngRepresentation.write(to: folder.appendingPathComponent("\(name).png"))
        if pause > 0 {
            RunLoop.current.run(until: Date().addingTimeInterval(pause))
        }
    }

    private func open(_ element: XCUIElement) -> Bool {
        guard element.waitForExistence(timeout: 10) else { return false }
        dismissSystemPrompts()
        element.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        return true
    }

    private func openTab(_ name: String) {
        dismissSystemPrompts()
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "tab \(name) not found")
        let maximumAttempts = 3
        for _ in 0 ..< maximumAttempts where !tab.isSelected {
            tab.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(1))
        }
    }

    private func goBack() {
        let back = app.navigationBars.buttons["BackButton"].firstMatch
        if back.waitForExistence(timeout: 5) {
            back.tap()
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    }

    private func scrollTo(_ element: XCUIElement) {
        let maximumSteps = 10
        var steps = 0
        while !(element.exists && element.isHittable), steps < maximumSteps {
            app.swipeUp()
            steps += 1
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
}
