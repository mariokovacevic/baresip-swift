import SwiftUI
import BaresipKit

struct Bubble: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: message.outgoing ? .trailing : .leading, spacing: 3) {
            Text(message.text)
                .font(.body)
                .foregroundStyle(foreground)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(background, in: RoundedRectangle(cornerRadius: 18))
            if let status = statusLine {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(isFailed ? Palette.destructive : Palette.secondaryText)
            }
        }
        .frame(maxWidth: 280, alignment: message.outgoing ? .trailing : .leading)
        .frame(maxWidth: .infinity, alignment: message.outgoing ? .trailing : .leading)
    }

    private var isFailed: Bool {
        if case .failed = message.status { return true }
        return false
    }

    private var foreground: Color {
        if isFailed { return Palette.secondaryText }
        return message.outgoing ? .white : .primary
    }

    private var background: Color {
        if isFailed { return Color(.systemGray6) }
        return message.outgoing ? Palette.blue : Color(.systemGray5)
    }

    private var statusLine: String? {
        switch message.status {
        case .sending: return "Sending…"
        case .delivered: return "Delivered"
        case .failed(let reason): return "Not delivered · \(reason)"
        case .received: return nil
        }
    }
}
