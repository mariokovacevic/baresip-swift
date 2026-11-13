import SwiftUI
import BaresipKit

struct SettingsView: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenTitle(title: "Settings")
                TitledSection(title: "Account") {
                    accountCard
                }
                TitledSection(title: "When a door rings") {
                    Card {
                        ToggleRow(title: "Reachable when Zvono is closed",
                                  detail: "Stays registered, so a push wakes the app for a ring",
                                  isOn: $model.settings.reachableInBackground)
                        RowDivider()
                        ToggleRow(title: "Hear the door before answering",
                                  detail: "The visitor cannot hear you until you answer",
                                  isOn: $model.settings.previewAudio)
                        RowDivider()
                        ToggleRow(title: "Picture in the notification",
                                  detail: "Shown while the phone rings, kept when you miss it",
                                  isOn: $model.settings.ringPicture)
                        RowDivider()
                        NavigationLink {
                            RingtoneView()
                        } label: {
                            LinkRowLabel(title: "Ringtone", value: model.ringtone.title)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.ringtone")
                        RowDivider()
                        NavigationLink {
                            CallScreenView()
                        } label: {
                            LinkRowLabel(title: "Call screen", value: model.callScreen.effective.title)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.callScreen")
                    }
                }
                TitledSection(title: "Doors") {
                    Card {
                        ForEach(model.doors) { door in
                            NavigationLink {
                                DoorView(door: door)
                            } label: {
                                LinkRowLabel(title: door.title, value: door.canOpen ? "Code set" : "No code")
                            }
                            .buttonStyle(.plain)
                            RowDivider()
                        }
                        NavigationLink {
                            DoorView(door: Door())
                        } label: {
                            Label("Add a door", systemImage: "plus")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Theme.info)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                TitledSection(title: "Contacts", note: "Call and write to them from the keypad.") {
                    Card {
                        ForEach(model.contacts) { contact in
                            NavigationLink {
                                ContactView(contact: contact)
                            } label: {
                                LinkRowLabel(title: contact.title, value: contact.address)
                            }
                            .buttonStyle(.plain)
                            RowDivider()
                        }
                        NavigationLink {
                            ContactView(contact: Contact())
                        } label: {
                            Label("Add a contact", systemImage: "plus")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Theme.info)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                TitledSection(title: "Support") {
                    Card {
                        NavigationLink {
                            DiagnosticsView()
                        } label: {
                            LinkRowLabel(title: "Diagnostics and log")
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("engine.link")
                        RowDivider()
                        ValueRow(title: "Recorded calls", value: "In the Files app")
                    }
                }
            }
            .padding(16)
        }
        .titledScreen("Settings")
        .onChange(of: model.settings.previewAudio) { _ in
            guard model.settings.isComplete else { return }
            Task { await model.saveAndRegister() }
        }
    }

    private var accountCard: some View {
        Card {
            NavigationLink {
                AccountView()
            } label: {
                LinkRowLabel(title: accountTitle)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("account.link")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                StatusDot(color: registrationColor)
                Text(registrationText)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("registration.state")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }

    private var accountTitle: String {
        guard model.settings.isComplete else { return "Set up account" }
        return "\(model.settings.username.trimmed) at \(model.settings.domain.trimmed)"
    }

    private var registrationText: String {
        switch model.registration {
        case .registered:
            let ca = model.caSummaries.isEmpty ? "system CA" : "private CA"
            let pins = model.settings.pinList.count
            let pinText = pins == 0 ? "" : ", \(pins) pin\(pins == 1 ? "" : "s")"
            return "Registered over \(model.settings.transportName.uppercased()), \(ca)\(pinText)"
        case .registering:
            return "Registering…"
        case .unregistering:
            return "Signing out…"
        case .failed:
            return "Registration failed\(model.registrationError.map { ": \($0)" } ?? "")"
        case .none:
            return model.registrationError ?? "Offline"
        }
    }

    private var registrationColor: Color {
        switch model.registration {
        case .registered: return Theme.info
        case .failed: return Theme.alert
        case .registering, .unregistering: return Theme.brass
        case .none: return Theme.secondary
        }
    }
}
