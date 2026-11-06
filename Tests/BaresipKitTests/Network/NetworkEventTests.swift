import XCTest
import BaresipKitBridge
import BaresipKitCore
@testable import BaresipKit

final class NetworkEventTests: XCTestCase {
    func testNetworkEventMapping() {
        var ev = bsk_event()
        bsk_bridge_make_network_event(&ev, true, "192.0.2.10")
        let mapped = withUnsafePointer(to: &ev) { BaresipEvent($0) }
        guard case .network(let net)? = mapped else {
            return XCTFail("expected network event, got \(String(describing: mapped))")
        }
        XCTAssertTrue(net.transportsReset)
        XCTAssertEqual(net.localAddress, "192.0.2.10")
    }

    func testEngineThreadAndABI() throws {
        let engine = try BaresipEngine(configuration: BaresipConfiguration())
        XCTAssertFalse(engine.isEngineThread)
        XCTAssertEqual(BaresipEngine.abiVersion.major, 0)
        XCTAssertEqual(BaresipEngine.abiVersion.minor, 6)
    }
}
