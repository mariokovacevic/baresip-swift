import XCTest
@testable import BaresipKit
@testable import BaresipKitSwiftUI

@MainActor
final class MessagePeerTests: XCTestCase {
    func testTheSameUserAndHostIsTheSamePeer() {
        XCTAssertTrue(BaresipPhoneCall.samePeer("\"Front door\" <sip:Door1@PBX.example.com:5061;transport=tls>",
                                                "sip:door1@pbx.example.com"))
        XCTAssertTrue(BaresipPhoneCall.samePeer("sips:door1@pbx.example.com?subject=x", "<sip:door1@pbx.example.com>"))
        XCTAssertTrue(BaresipPhoneCall.samePeer("sip:100@[2001:db8::1]:5060", "sip:100@[2001:db8::1]"))
    }

    func testAUserWithoutHostMatchesAnyHost() {
        XCTAssertTrue(BaresipPhoneCall.samePeer("door1", "sip:door1@pbx.example.com"))
        XCTAssertTrue(BaresipPhoneCall.samePeer("tel:+15555550100", "sip:+15555550100@pbx.example.com"))
    }

    func testOtherUsersOrHostsAreOtherPeers() {
        XCTAssertFalse(BaresipPhoneCall.samePeer("sip:door2@pbx.example.com", "sip:door1@pbx.example.com"))
        XCTAssertFalse(BaresipPhoneCall.samePeer("sip:door1@other.example.com", "sip:door1@pbx.example.com"))
        XCTAssertFalse(BaresipPhoneCall.samePeer("sip:door10@pbx.example.com", "sip:door1@pbx.example.com"))
        XCTAssertFalse(BaresipPhoneCall.samePeer("", "sip:door1@pbx.example.com"))
        XCTAssertFalse(BaresipPhoneCall.samePeer("sip:@pbx.example.com", "sip:@pbx.example.com"))
    }

    func testAMessageBelongsToTheEstablishedCallWithItsSender() throws {
        var configuration = BaresipConfiguration()
        configuration.modules = ["g711"]
        configuration.extraConfiguration = "sip_listen\t\t0.0.0.0:0"
        let phone = try BaresipPhone(engine: BaresipEngine(configuration: configuration))
        let door = BaresipCallID(rawValue: 1)
        let neighbour = BaresipCallID(rawValue: 2)
        let ringing = BaresipCallID(rawValue: 3)
        phone.apply(.incomingCall(info(door, "sip:door1@pbx.example.com"), earlyVideo: false))
        phone.apply(.call(door, .streamsRunning, nil))
        phone.apply(.incomingCall(info(neighbour, "sip:101@pbx.example.com"), earlyVideo: false))
        phone.apply(.call(neighbour, .paused, nil))
        phone.apply(.incomingCall(info(ringing, "sip:gate@pbx.example.com"), earlyVideo: false))

        XCTAssertEqual(phone.call(withPeer: "\"Front door\" <sip:door1@pbx.example.com>")?.id, door)
        XCTAssertEqual(phone.call(withPeer: "sip:101@pbx.example.com")?.id, neighbour)
        XCTAssertNil(phone.call(withPeer: "sip:gate@pbx.example.com"))
        XCTAssertNil(phone.call(withPeer: "sip:202@pbx.example.com"))

        phone.apply(.call(door, .ended, nil))
        XCTAssertNil(phone.call(withPeer: "sip:door1@pbx.example.com"))
    }

    private func info(_ id: BaresipCallID, _ uri: String) -> BaresipCallInfo {
        BaresipCallInfo(id: id, account: BaresipAccountID(rawValue: 1), state: .incoming, isOutgoing: false,
                        hasVideo: false, audioDirection: .sendReceive, videoDirection: .inactive, sipCallID: "",
                        remoteURI: uri, remoteDisplayName: "", audioCodec: "", videoCodec: "", setupTime: .zero,
                        duration: .zero, isMicrophoneMuted: false, replacesCallID: nil)
    }
}
