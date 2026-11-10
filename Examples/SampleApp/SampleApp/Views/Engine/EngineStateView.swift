import SwiftUI
import BaresipKit
import BaresipKitSwiftUI

struct EngineStateView: View {
    @ObservedObject var phone: BaresipPhone

    var body: some View {
        List {
            Section("Registrations") {
                if phone.registrations.isEmpty {
                    Text("No account reported yet")
                        .foregroundStyle(Palette.secondaryText)
                }
                ForEach(sortedRegistrations, id: \.account) { entry in
                    Text("Account \(entry.account.rawValue): \(String(describing: entry.state))")
                        .accessibilityIdentifier("engine.registration")
                }
            }
            Section("Calls") {
                if phone.calls.isEmpty {
                    Text("No calls")
                        .foregroundStyle(Palette.secondaryText)
                }
                ForEach(phone.calls) { call in
                    EngineCallRow(call: call)
                }
            }
        }
        .navigationTitle("Engine state")
    }

    private var sortedRegistrations: [(account: BaresipAccountID, state: BaresipRegistrationState)] {
        phone.registrations
            .map { (account: $0.key, state: $0.value) }
            .sorted { $0.account.rawValue < $1.account.rawValue }
    }
}
