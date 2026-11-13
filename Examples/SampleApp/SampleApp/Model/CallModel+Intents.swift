import Foundation

enum DoorIntentError: Error, CustomLocalizedStringResourceConvertible {
    case unknownDoor
    case notRegistered

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .unknownDoor: "That door has no code to open it."
        case .notRegistered: "Zvono could not reach your server."
        }
    }
}

extension CallModel {
    func openFromIntent(doorID: UUID) async throws -> Door {
        guard let door = doors.first(where: { $0.id == doorID }), door.canOpen else {
            throw DoorIntentError.unknownDoor
        }
        if let incoming, self.door(of: incoming)?.id == door.id {
            await openDoor(incoming, with: door)
            return door
        }
        if let activeCall, self.door(of: activeCall)?.id == door.id {
            await sendDTMFRequest(door.openRequest)
            return door
        }
        await start()
        try await waitForRegistration(timeout: .seconds(15))
        await open(door, confirmingOwner: false)
        return door
    }

    private func waitForRegistration(timeout: Duration) async throws {
        let deadline = ContinuousClock.now + timeout
        while registration != .registered {
            guard ContinuousClock.now < deadline else { throw DoorIntentError.notRegistered }
            try await Task.sleep(for: .milliseconds(200))
        }
    }
}
