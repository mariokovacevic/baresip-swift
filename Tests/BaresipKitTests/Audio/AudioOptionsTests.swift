#if os(iOS)
    import AVFoundation
    import XCTest
    @testable import BaresipKitAudio

    final class AudioOptionsTests: XCTestCase {
        func testBluetoothFlagControlsBothProfiles() {
            let on = BaresipAudioSessionController.voipCategoryOptions(allowBluetooth: true, defaultToSpeaker: false)
            let off = BaresipAudioSessionController.voipCategoryOptions(allowBluetooth: false, defaultToSpeaker: true)
            XCTAssertTrue(on.contains(.allowBluetoothA2DP))
            XCTAssertFalse(on.contains(.defaultToSpeaker))
            XCTAssertFalse(off.contains(.allowBluetoothA2DP))
            XCTAssertTrue(off.contains(.defaultToSpeaker))
            #if compiler(>=6.2)
                XCTAssertTrue(on.contains(.allowBluetoothHFP))
                XCTAssertFalse(off.contains(.allowBluetoothHFP))
            #else
                XCTAssertTrue(on.contains(.allowBluetooth))
                XCTAssertFalse(off.contains(.allowBluetooth))
            #endif
        }

        func testPortTypesMapToRoutes() {
            XCTAssertEqual(BaresipAudioSessionController.route(for: .builtInReceiver), .earpiece)
            XCTAssertEqual(BaresipAudioSessionController.route(for: .builtInSpeaker), .speaker)
            XCTAssertEqual(BaresipAudioSessionController.route(for: .bluetoothHFP), .bluetooth)
            XCTAssertEqual(BaresipAudioSessionController.route(for: .bluetoothA2DP), .bluetooth)
            XCTAssertEqual(BaresipAudioSessionController.route(for: .headsetMic), .wiredHeadset)
            XCTAssertEqual(BaresipAudioSessionController.route(for: .headphones), .wiredHeadset)
            XCTAssertEqual(
                BaresipAudioSessionController.route(for: .carAudio),
                .other(AVAudioSession.Port.carAudio.rawValue)
            )
        }

        func testFixedOutputsHaveDistinctIDs() {
            XCTAssertNotEqual(BaresipAudioOutput.earpiece.id, BaresipAudioOutput.speaker.id)
            XCTAssertEqual(BaresipAudioOutput.speaker.route, .speaker)
        }

        func testOnlyDeviceChangesRestartAudio() {
            XCTAssertTrue(BaresipAudioSessionController.restartsAudio(.newDeviceAvailable))
            XCTAssertTrue(BaresipAudioSessionController.restartsAudio(.oldDeviceUnavailable))
            XCTAssertFalse(BaresipAudioSessionController.restartsAudio(.categoryChange))
            XCTAssertFalse(BaresipAudioSessionController.restartsAudio(.routeConfigurationChange))
            XCTAssertFalse(BaresipAudioSessionController.restartsAudio(.override))
            XCTAssertFalse(BaresipAudioSessionController.restartsAudio(nil))
        }
    }
#endif
