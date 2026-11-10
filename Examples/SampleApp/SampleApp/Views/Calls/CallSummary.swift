import SwiftUI
import BaresipKit

struct CallSummary: View {
    let row: CallRow
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Avatar(initials: row.initials, tint: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.headline)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(callStatusText(row, now: context.date))
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(color)
                }
            }
        }
    }
}
