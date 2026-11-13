import SwiftUI

/// A label on the left and a text field on the right, inside a card.
struct FieldRow: View {
    let title: String
    @Binding var text: String
    var prompt = ""
    var identifier: String?
    var keyboard: UIKeyboardType = .default
    var secure = false

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(Theme.text)
                .layoutPriority(1)
            Group {
                if secure {
                    SecretField(title: title, text: $text, prompt: prompt)
                } else {
                    TextField(title, text: $text, prompt: Text(prompt))
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .multilineTextAlignment(.trailing)
            .foregroundStyle(Theme.secondary)
            .accessibilityIdentifier(identifier ?? "")
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
    }
}

/// A choice shown as a menu on the right.
struct MenuRow<Value: Hashable, Options: View>: View {
    let title: String
    @Binding var selection: Value
    @ViewBuilder let options: Options

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(Theme.text)
            Spacer(minLength: 8)
            Picker(title, selection: $selection) {
                options
            }
            .labelsHidden()
            .tint(Theme.secondary)
        }
        .font(.subheadline)
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .frame(minHeight: 50)
    }
}

/// A short choice shown as segments on the right.
struct SegmentRow<Value: Hashable, Options: View>: View {
    let title: String
    @Binding var selection: Value
    var identifier: String?
    @ViewBuilder let options: Options

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(Theme.text)
            Spacer(minLength: 8)
            Picker(title, selection: $selection) {
                options
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .accessibilityIdentifier(identifier ?? "")
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.leading, 4)
        .frame(minHeight: 50)
    }
}

/// A number changed in steps, with its value shown next to the title.
struct StepperRow: View {
    let title: String
    let value: String
    @Binding var number: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        Stepper(value: $number, in: range, step: step) {
            HStack {
                Text(title)
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 8)
                Text(value)
                    .foregroundStyle(Theme.secondary)
                    .monospacedDigit()
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
    }
}

/// A plain action inside a card, in the link color or as a destructive action.
struct CardButton: View {
    let title: String
    var role: ButtonRole?
    var identifier: String?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(role == .destructive ? Theme.alert : Theme.info)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier ?? "")
    }
}
