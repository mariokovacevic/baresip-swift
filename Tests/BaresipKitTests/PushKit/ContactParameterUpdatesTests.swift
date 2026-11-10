import XCTest
import BaresipKit
@testable import BaresipKitPushKit

final class ContactParameterUpdatesTests: XCTestCase {
    private typealias Request = ContactParameterUpdates.Request

    private let account = BaresipAccountID(rawValue: 1)

    private func request(_ appID: String) -> Request {
        Request(accountID: account, parameters: [BaresipContactParameter("app-id", appID)])
    }

    func testTheFirstUpdateStartsSending() {
        var updates = ContactParameterUpdates()

        XCTAssertTrue(updates.submit(request("first")))
        XCTAssertEqual(updates.next(), request("first"))
        XCTAssertNil(updates.next())
    }

    func testUpdatesSubmittedWhileSendingAreCoalescedIntoTheLatest() {
        var updates = ContactParameterUpdates()
        XCTAssertTrue(updates.submit(request("first")))
        XCTAssertEqual(updates.next(), request("first"))

        XCTAssertFalse(updates.submit(request("second")))
        XCTAssertFalse(updates.submit(request("third")))

        XCTAssertEqual(updates.next(), request("third"))
        XCTAssertNil(updates.next())
    }

    func testAnUpdateBeforeTheSenderRunsReplacesTheQueuedOne() {
        var updates = ContactParameterUpdates()
        XCTAssertTrue(updates.submit(request("first")))
        XCTAssertFalse(updates.submit(request("second")))

        XCTAssertEqual(updates.next(), request("second"))
        XCTAssertNil(updates.next())
    }

    func testSendingStartsAgainAfterTheQueueWasDrained() {
        var updates = ContactParameterUpdates()
        XCTAssertTrue(updates.submit(request("first")))
        XCTAssertEqual(updates.next(), request("first"))
        XCTAssertNil(updates.next())

        XCTAssertTrue(updates.submit(request("second")))
        XCTAssertEqual(updates.next(), request("second"))
    }

    func testAdditionalParametersFollowThePushParameters() {
        let tokens = BaresipPushTokens(appID: "com.example.app", voipToken: Data([0xAB, 0xCD]))
        let parameters = tokens.mergedContactParameters(with: [BaresipContactParameter("x-device", "door-1")])

        XCTAssertEqual(Array(parameters.prefix(tokens.contactParameters.count)), tokens.contactParameters)
        XCTAssertEqual(parameters.last, BaresipContactParameter("x-device", "door-1"))
    }

    func testAnAdditionalParameterNeverReplacesAPushParameter() {
        let tokens = BaresipPushTokens(appID: "com.example.app", voipToken: Data([0xAB, 0xCD]))
        let parameters = tokens.mergedContactParameters(with: [
            BaresipContactParameter("PN-Tok", "forged"),
            BaresipContactParameter("x-device", "door-1"),
        ])

        XCTAssertEqual(parameters.filter { $0.name.lowercased() == "pn-tok" }.map(\.value), ["abcd:voip"])
        XCTAssertEqual(parameters.count, tokens.contactParameters.count + 1)
    }

    func testWithoutAdditionalParametersOnlyThePushParametersAreSent() {
        let tokens = BaresipPushTokens(appID: "com.example.app")

        XCTAssertEqual(tokens.mergedContactParameters(with: []), tokens.contactParameters)
    }
}
