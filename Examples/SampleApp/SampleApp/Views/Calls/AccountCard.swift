import SwiftUI
import BaresipKit

struct AccountCard: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                AccountView()
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(registrationColor)
                        .frame(width: 10, height: 10)
                        .accessibilityHidden(true)
                    Text(model.settings.isComplete ? model.settings.aor : "Set up account")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Palette.secondaryText)
                }
                .frame(minHeight: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("account.link")

            Text(registrationText)
                .font(.footnote)
                .foregroundStyle(registrationTextColor)
                .padding(.leading, 22)
                .accessibilityIdentifier("registration.state")

            if model.settings.isComplete {
                HStack(spacing: 16) {
                    Button("Register") { Task { await model.register() } }
                    Button("Unregister") { Task { await model.unregister() } }
                }
                .font(.subheadline)
                .padding(.leading, 22)
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var registrationText: String {
        switch model.registration {
        case .registered:
            let ca = model.caSummaries.isEmpty ? "system CA" : "private CA"
            let pins = model.settings.pinList.count
            let pinText = pins == 0 ? "" : " · \(pins) pin\(pins == 1 ? "" : "s")"
            return "Registered over \(model.settings.transportName.uppercased()) · \(ca)\(pinText)"
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
        case .registered: return Palette.signalGreen
        case .failed: return Palette.signalRed
        case .registering, .unregistering: return Palette.signalOrange
        case .none: return Color(.systemGray3)
        }
    }

    private var registrationTextColor: Color {
        switch model.registration {
        case .registered: return Palette.green
        case .failed: return Palette.destructive
        default: return Palette.secondaryText
        }
    }
}
