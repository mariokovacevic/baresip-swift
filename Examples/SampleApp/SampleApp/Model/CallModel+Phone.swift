import Combine
import Foundation
import BaresipKit
import BaresipKitSwiftUI

/// The call state the screens show, read from `BaresipPhone`.
extension CallModel {
    var calls: [CallRow] {
        (phone?.calls ?? []).map { CallRow(call: $0, dtmf: dtmfStates[$0.id]) }
    }

    var activeCall: BaresipPhoneCall? {
        phone?.activeCall
    }

    var currentCall: BaresipCallID? {
        activeCall?.id
    }

    var currentRow: CallRow? {
        activeCall.map { CallRow(call: $0, dtmf: dtmfStates[$0.id]) }
    }

    /// The other call on hold, while the current call is a consultation or a second call.
    var heldCall: BaresipCallID? {
        phone?.calls.first { $0.id != currentCall && $0.isOnHold }?.id
    }

    var heldRow: CallRow? {
        guard let heldCall, let call = phone?.call(heldCall) else { return nil }
        return CallRow(call: call, dtmf: dtmfStates[heldCall])
    }

    /// The ringing call to show: the one opened from the call list, or the first.
    var incoming: BaresipPhoneCall? {
        if let shownIncoming, let call = phone?.call(shownIncoming), call.isRinging {
            return call
        }
        return phone?.incomingCall
    }

    var callState: BaresipCallState? {
        activeCall?.state
    }

    var muted: Bool {
        activeCall?.isMuted ?? false
    }

    var onHold: Bool {
        activeCall?.isOnHold ?? false
    }

    var sendingVideo: Bool {
        activeCall?.isSendingVideo ?? false
    }

    var receivingVideo: Bool {
        activeCall?.isReceivingVideo ?? false
    }

    /// Passes changes of the phone and of each of its calls on as changes of this model, and
    /// notices calls that start and end.
    func observe(_ phone: BaresipPhone?) {
        phoneObservers = []
        callObservers = [:]
        guard let phone else { return }
        phone.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &phoneObservers)
        phone.$calls
            .sink { [weak self] calls in self?.callsChanged(calls) }
            .store(in: &phoneObservers)
    }

    private func callsChanged(_ calls: [BaresipPhoneCall]) {
        let ids = Set(calls.map(\.id))
        for call in calls where callObservers[call.id] == nil {
            knownCalls[call.id] = call
            callObservers[call.id] = call.objectWillChange
                .sink { [weak self] _ in self?.objectWillChange.send() }
        }
        for (id, call) in knownCalls where !ids.contains(id) {
            callObservers[id] = nil
            knownCalls[id] = nil
            let remaining = calls.count
            Task { await callEnded(call, remainingCalls: remaining) }
        }
    }
}
