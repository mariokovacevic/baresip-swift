#if canImport(UIKit)
    import XCTest
    @testable import BaresipKit

    @MainActor
    final class AppLifecycleTests: XCTestCase {
        private func makeEngine() throws -> BaresipEngine {
            var configuration = BaresipConfiguration(instanceUUID: UUID())
            configuration.modules = ["g711"]
            configuration.audio.sourceModule = "ausine"
            configuration.audio.playerModule = "aufile"
            configuration.audio.playerDevice = "/dev/null"
            configuration.extraConfiguration = "sip_listen\t\t0.0.0.0:0"
            return try BaresipEngine(configuration: configuration)
        }

        func testTheEngineIsSuspendedInTheBackgroundAndResumedInTheForeground() async throws {
            let engine = try makeEngine()
            try await engine.start()
            let lifecycle = BaresipAppLifecycle(engine: engine)
            lifecycle.usesBackgroundTasks = false
            var changes: [BaresipAppLifecycle.Change] = []
            lifecycle.setChangeHandler { changes.append($0) }

            lifecycle.didEnterBackground()
            await lifecycle.goAwayIfIdle()
            XCTAssertTrue(lifecycle.isAway)

            lifecycle.didBecomeActive()
            XCTAssertFalse(lifecycle.isAway)
            for _ in 0 ..< 100 where changes.count < 2 {
                try await Task.sleep(for: .milliseconds(10))
            }
            await engine.stop()

            XCTAssertEqual(changes, [.suspended, .backOnline])
        }

        func testAccountsGoOfflineInTheBackgroundAndRegisterAgainWhenActive() async throws {
            let engine = try makeEngine()
            try await engine.start()
            let account = try await engine.addAccount(
                BaresipAccountConfiguration(aor: "sip:alice@127.0.0.1:9", transport: .udp)
            )
            try await engine.register(accountID: account)
            let lifecycle = BaresipAppLifecycle(engine: engine)
            lifecycle.usesBackgroundTasks = false
            lifecycle.backgroundBehavior = .goOffline
            lifecycle.unregisterTimeout = .milliseconds(300)
            var changes: [BaresipAppLifecycle.Change] = []
            lifecycle.setChangeHandler { changes.append($0) }

            lifecycle.didEnterBackground()
            await lifecycle.goAwayIfIdle()
            XCTAssertTrue(lifecycle.isAway)
            let offline = await engine.accounts()[account]
            XCTAssertNotEqual(offline, .registered)
            XCTAssertNotEqual(offline, .registering)

            lifecycle.didBecomeActive()
            for _ in 0 ..< 100 where changes.count < 2 {
                try await Task.sleep(for: .milliseconds(10))
            }
            let online = await engine.accounts()[account]
            await engine.stop()

            XCTAssertFalse(lifecycle.isAway)
            XCTAssertEqual(changes, [.wentOffline, .backOnline])
            XCTAssertNotEqual(online, BaresipRegistrationState.none)
        }

        func testNothingIsSuspendedWhenTurnedOff() async throws {
            let engine = try makeEngine()
            try await engine.start()
            let lifecycle = BaresipAppLifecycle(engine: engine)
            lifecycle.backgroundBehavior = .stayOnline

            lifecycle.didEnterBackground()
            await lifecycle.goAwayIfIdle()
            await engine.stop()

            XCTAssertFalse(lifecycle.isAway)
        }

        func testAStoppedEngineIsNotSuspended() async throws {
            let lifecycle = try BaresipAppLifecycle(engine: makeEngine())

            lifecycle.didEnterBackground()
            await lifecycle.goAwayIfIdle()

            XCTAssertFalse(lifecycle.isAway)
        }

        func testTerminationStopsTheEngine() async throws {
            let engine = try makeEngine()
            try await engine.start()
            let lifecycle = BaresipAppLifecycle(engine: engine)
            var changes: [BaresipAppLifecycle.Change] = []
            lifecycle.setChangeHandler { changes.append($0) }

            lifecycle.willTerminate()

            XCTAssertEqual(engine.state, .stopped)
            XCTAssertEqual(changes, [.disconnected])
        }
    }
#endif
