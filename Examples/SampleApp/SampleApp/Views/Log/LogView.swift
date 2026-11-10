import SwiftUI
import BaresipKit

struct LogView: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        List {
            Section {
                Toggle("Log SIP messages", isOn: $model.logsSIPMessages)
                    .accessibilityIdentifier("log.sipMessages")
            } footer: {
                Text(
                    """
                    SIP messages show who you call and who calls you, and digits sent as DTMF over SIP INFO. \
                    They go to the log files, which are kept for seven days and can be shared from here, and \
                    to the system log. A change applies the next time the app starts.
                    """
                )
            }
            Section {
                ForEach(Array(model.log.enumerated().reversed()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption.monospaced())
                }
            }
        }
        .navigationTitle("Log")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(items: FileLog.shared.files()) {
                    Label("Share logs", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("log.share")
            }
        }
    }
}
