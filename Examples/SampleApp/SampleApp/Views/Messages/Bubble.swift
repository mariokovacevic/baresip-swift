import SwiftUI
import BaresipKit

struct Bubble: View {
    @EnvironmentObject private var model: CallModel
    let message: ChatMessage

    var body: some View {
        VStack(alignment: message.outgoing ? .trailing : .leading, spacing: 4) {
            Text(message.text)
                .font(.body)
                .foregroundStyle(message.outgoing && !isFailed ? Theme.background : Theme.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(background, in: shape)
                .overlay(shape.stroke(border))
            if isFailed {
                Button("Not delivered. Send again") {
                    Task { await model.resend(message) }
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.alert)
                .frame(minHeight: 44)
                .padding(.horizontal, 6)
            } else {
                Text(statusLine)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondary)
                    .padding(.horizontal, 6)
            }
        }
        .frame(maxWidth: 280, alignment: message.outgoing ? .trailing : .leading)
        .frame(maxWidth: .infinity, alignment: message.outgoing ? .trailing : .leading)
    }

    private var shape: UnevenBubble {
        UnevenBubble(outgoing: message.outgoing)
    }

    private var isFailed: Bool {
        if case .failed = message.status {
            return true
        }
        return false
    }

    private var background: Color {
        if isFailed {
            return Theme.failed
        }
        return message.outgoing ? Theme.text : Theme.surface
    }

    private var border: Color {
        if isFailed {
            return Theme.failedLine
        }
        return message.outgoing ? .clear : Theme.line
    }

    private var statusLine: String {
        let time = message.date.formatted(date: .omitted, time: .shortened)
        switch message.status {
        case .sending: return "Sending"
        case .delivered: return "\(time), delivered"
        case .failed, .received: return time
        }
    }
}

/// A bubble with a smaller corner on the sender's side, at the bottom.
struct UnevenBubble: Shape {
    let outgoing: Bool

    func path(in rect: CGRect) -> Path {
        let large: CGFloat = 18
        let small: CGFloat = 6
        let bottomLeft = outgoing ? large : small
        let bottomRight = outgoing ? small : large
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + large, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - large, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + large), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bottomLeft),
                          control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + large))
        path.addQuadCurve(to: CGPoint(x: rect.minX + large, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
