import XCTest
@testable import BaresipKit

final class NetworkMonitorTests: XCTestCase {
    func testFirstPathIsNeverNotified() {
        let path = BaresipNetworkPath(interfaceSummary: "wifi", isSatisfied: true)
        XCTAssertFalse(BaresipNetworkMonitor.shouldNotifyEngine(current: path, previous: nil))
    }

    func testUnsatisfiedPathIsNotNotified() {
        let previous = BaresipNetworkPath(interfaceSummary: "wifi", isSatisfied: true)
        let current = BaresipNetworkPath(interfaceSummary: "", isSatisfied: false)
        XCTAssertFalse(BaresipNetworkMonitor.shouldNotifyEngine(current: current, previous: previous))
    }

    func testRepeatOfTheSameSummaryIsNotNotified() {
        let previous = BaresipNetworkPath(interfaceSummary: "wifi", isSatisfied: true)
        let current = BaresipNetworkPath(interfaceSummary: "wifi", isSatisfied: true)
        XCTAssertFalse(BaresipNetworkMonitor.shouldNotifyEngine(current: current, previous: previous))
    }

    func testChangedSatisfiedSummaryIsNotified() {
        let previous = BaresipNetworkPath(interfaceSummary: "wifi", isSatisfied: true)
        let current = BaresipNetworkPath(interfaceSummary: "cellular", isSatisfied: true)
        XCTAssertTrue(BaresipNetworkMonitor.shouldNotifyEngine(current: current, previous: previous))
    }

    func testStartAndStopDoNotCrash() throws {
        let engine = try BaresipEngine(configuration: BaresipConfiguration(instanceUUID: UUID()))
        let monitor = BaresipNetworkMonitor(engine: engine)
        let expectation = expectation(description: "handler set")
        monitor.setChangeHandler { _ in }
        monitor.start()
        monitor.stop()
        expectation.fulfill()
        wait(for: [expectation], timeout: 1)
    }
}
