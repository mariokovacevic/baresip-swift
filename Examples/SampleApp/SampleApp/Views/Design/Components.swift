import SwiftUI

/// A rounded panel on the dark ground; rows inside it are separated by ``RowDivider``.
struct Card<Content: View>: View {
    var radius: CGFloat = 20
    var highlighted = false
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: shape)
        .overlay(shape.stroke(highlighted ? Theme.raisedLine : Theme.line))
    }
}

struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(height: 1)
    }
}

/// A small uppercase heading above a card.
struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .textCase(.uppercase)
            .font(.footnote.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A heading, its card and an optional note below it.
struct TitledSection<Content: View>: View {
    let title: String
    var note: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: title)
            content
            if let note {
                Note(text: note)
            }
        }
    }
}

struct Note: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Theme.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }
}

/// A switch with a title and an optional line below it.
struct ToggleRow: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(Theme.text)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary)
                }
            }
        }
        .tint(Theme.brass)
        .padding(.horizontal, 16)
        .frame(minHeight: detail == nil ? 50 : 60)
    }
}

/// A row that leads somewhere, with a value and a chevron.
struct LinkRowLabel: View {
    let title: String
    var value: String?
    var systemImage: String?

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(Theme.secondary)
                    .frame(width: 22)
                    .accessibilityHidden(true)
            }
            Text(title)
                .foregroundStyle(Theme.text)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

/// A label on the left and a value on the right.
struct ValueRow: View {
    let title: String
    let value: String
    var valueIdentifier: String?

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(Theme.text)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.trailing)
                .accessibilityIdentifier(valueIdentifier ?? "")
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
    }
}

/// The large title at the top of a screen, in the display face.
struct ScreenTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.display(36, relativeTo: .largeTitle))
            .foregroundStyle(Theme.text)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    /// Names the screen for the back button and VoiceOver while ``ScreenTitle`` shows it large:
    /// the bar keeps its buttons and leaves the title out.
    func titledScreen(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityHidden(true)
                }
            }
    }
}

/// A password or code: dots while it is not edited, the secure field while it is.
struct SecretField: View {
    let title: String
    @Binding var text: String
    var prompt = ""
    var keyboard: UIKeyboardType = .default
    var identifier: String?
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .trailing) {
            SecureField(title, text: $text, prompt: Text(prompt))
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .focused($focused)
                .opacity(focused || text.isEmpty ? 1 : 0.02)
                .accessibilityIdentifier(identifier ?? "")
            if !focused, !text.isEmpty {
                Text(String(repeating: "\u{2022}", count: min(text.count, 10)))
                    .tracking(2)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}
