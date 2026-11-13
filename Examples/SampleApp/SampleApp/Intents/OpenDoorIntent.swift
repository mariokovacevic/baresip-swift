import AppIntents
import Foundation

struct DoorEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Door"
    static let defaultQuery = DoorQuery()

    let id: UUID
    let title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    init(_ door: Door) {
        id = door.id
        title = door.title
    }
}

struct DoorQuery: EntityStringQuery {
    private var openableDoors: [DoorEntity] {
        SettingsStore.doors.filter(\.canOpen).map(DoorEntity.init)
    }

    func entities(for identifiers: [UUID]) async throws -> [DoorEntity] {
        openableDoors.filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [DoorEntity] {
        openableDoors.filter { $0.title.localizedCaseInsensitiveContains(string) }
    }

    func suggestedEntities() async throws -> [DoorEntity] {
        openableDoors
    }
}

struct OpenDoorIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Door"
    static let description = IntentDescription(
        "Sends the door's code: on its call when it rings or talks, otherwise on a short call."
    )
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Door")
    var door: DoorEntity

    init() {}

    init(door: DoorEntity) {
        self.door = door
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let opened = try await CallModel.shared.openFromIntent(doorID: door.id)
        return .result(dialog: "Opening \(opened.title).")
    }
}

struct ZvonoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenDoorIntent(),
                    phrases: [
                        "Open \(\.$door) with \(.applicationName)",
                        "\(.applicationName) open \(\.$door)",
                    ],
                    shortTitle: "Open Door",
                    systemImageName: "key")
    }
}
