import Foundation
import BaresipKit
import BaresipKitSwiftUI

extension CallModel {
    func recordHistory(_ call: BaresipPhoneCall) {
        let snapshot = snapshots.finish(call.id)
        let row = CallRow(call: call, dtmf: dtmfStates[call.id])
        history.insert(CallRecord(row: row, snapshotFile: snapshot), at: 0)
        if history.count > SettingsStore.historyLimit {
            history.removeLast(history.count - SettingsStore.historyLimit)
        }
    }

    func redial(_ record: CallRecord) {
        destination = record.uri.isEmpty ? record.name : record.uri
    }

    enum Repeat {
        case same, audio, video
    }

    /// Places the recent call again: the same kind it was, or audio or video.

    func repeatCall(_ record: CallRecord, as kind: Repeat) async {
        redial(record)
        switch kind {
        case .same:
            if let request = record.dtmfRequest {
                await sendDTMFRequest(request)
            } else {
                await call(video: record.video)
            }
        case .audio:
            await call(video: false)
        case .video:
            await call(video: true)
        }
    }
}
