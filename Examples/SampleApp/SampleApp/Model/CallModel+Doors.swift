import Foundation
import LocalAuthentication
import BaresipKit
import BaresipKitSwiftUI

/// The doors the user saved: which call comes from which door, and opening them.
extension CallModel {
    func door(for remote: String) -> Door? {
        let user = CallRow.displayName(remote)
        guard !user.isEmpty else { return nil }
        return doors.first { !$0.user.isEmpty && $0.user == user }
    }

    func door(of call: BaresipPhoneCall?) -> Door? {
        call.flatMap { door(for: $0.remoteURI) }
    }

    /// The door of the current call, when it can be opened.
    var currentDoor: Door? {
        door(of: activeCall).flatMap { $0.canOpen ? $0 : nil }
    }

    /// The door of the ringing call, when it can be opened.
    var ringingDoor: Door? {
        door(of: incoming).flatMap { $0.canOpen ? $0 : nil }
    }

    /// Whether the code of the current call's door was sent.
    var currentDoorOpened: Bool {
        guard let currentCall, let state = dtmfStates[currentCall] else { return false }
        return state.sent && !(state.result?.hasPrefix("failed") ?? false)
    }

    func save(_ door: Door) {
        if let index = doors.firstIndex(where: { $0.id == door.id }) {
            doors[index] = door
        } else {
            doors.append(door)
        }
    }

    func remove(_ door: Door) {
        doors.removeAll { $0.id == door.id }
    }

    /// The latest call from or to the door.
    func lastRecord(of door: Door) -> CallRecord? {
        history.first { $0.user == door.user }
    }

    /// Opens the door: on its call when one runs, otherwise on a new audio call that sends the
    /// code once connected and hangs up if the door asks for it.
    func open(_ door: Door, confirmingOwner: Bool = true) async {
        guard door.canOpen else { return }
        if confirmingOwner {
            guard await confirmOwner(for: door) else { return }
        }
        destination = door.address
        if let activeCall, self.door(of: activeCall)?.id == door.id {
            await sendDTMFRequest(door.openRequest)
        } else {
            pendingDTMF = door.openRequest
            await call(video: false)
        }
    }

    /// Calls the door to see and hear who is there; the camera stays off.
    func look(at door: Door) async {
        destination = door.address
        await call(video: false)
    }

    /// Sends the code of the current call's door.
    func openCurrentDoor() async {
        guard let door = currentDoor, await confirmOwner(for: door) else { return }
        await sendDTMFRequest(door.openRequest)
    }

    /// Answers the ringing door without the camera, sends its code and hangs up if it asks to.
    func openRingingDoor() async {
        guard let incoming, let door = ringingDoor, await confirmOwner(for: door) else { return }
        await openDoor(incoming, with: door)
    }

    func openDoor(_ call: BaresipPhoneCall, with door: Door) async {
        dtmfStates[call.id] = DTMFState(request: door.openRequest)
        do {
            try await call.answer(video: false)
        } catch {
            dtmfStates[call.id] = nil
            append("open door failed: \(error)")
            return
        }
        didAnswer(call.id)
    }

    private func confirmOwner(for door: Door) async -> Bool {
        guard door.asksForFaceID else { return true }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            append("no Face ID or passcode on this phone: opening \(door.title) without it")
            return true
        }
        let reason = "Open \(door.title)"
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
