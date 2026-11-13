import XCTest
import BaresipKitBridge
import BaresipKitCore
@testable import BaresipKit

final class CallEndReasonTests: XCTestCase {
    private func ended(status: UInt16, reason: bsk_call_end_reason) -> BaresipEvent? {
        var ev = bsk_event()
        ev.type = BSK_EVENT_CALL_STATE
        ev.call = 7
        ev.u.call_state.state = BSK_CALL_ENDED
        ev.u.call_state.error.status = BSK_OK
        ev.u.call_state.error.sip_status = status
        ev.u.call_state.end_reason = reason
        return withUnsafePointer(to: &ev) { BaresipEvent($0) }
    }

    func testACallAnsweredOnAnotherDeviceSaysSo() {
        guard case .call(_, .ended, let error?)? = ended(status: 200, reason: BSK_END_ANSWERED_ELSEWHERE) else {
            return XCTFail("expected an ended call with its reason")
        }
        XCTAssertEqual(error.endReason, .answeredElsewhere)
        XCTAssertEqual(error.sipStatus, 200)
        XCTAssertFalse(error.isFailure)
    }

    func testACallDeclinedOnAnotherDeviceSaysSo() {
        guard case .call(_, .ended, let error?)? = ended(status: 603, reason: BSK_END_DECLINED_ELSEWHERE) else {
            return XCTFail("expected an ended call with its reason")
        }
        XCTAssertEqual(error.endReason, .declinedElsewhere)
    }

    func testAnOrdinaryEndHasNoReason() {
        guard case .call(_, .ended, let error)? = ended(status: 0, reason: BSK_END_NORMAL) else {
            return XCTFail("expected an ended call")
        }
        XCTAssertNil(error)
    }
}
