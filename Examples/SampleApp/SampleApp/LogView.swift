import SwiftUI
import BaresipKit

struct LogView: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        List(Array(model.log.enumerated().reversed()), id: \.offset) { _, line in
            Text(line)
                .font(.caption.monospaced())
        }
        .navigationTitle("Log")
    }
}
