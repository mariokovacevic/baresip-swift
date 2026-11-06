import AVFoundation
import XCTest
import BaresipKitAudio

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
}
