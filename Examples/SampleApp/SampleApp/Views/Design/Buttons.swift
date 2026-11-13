import SwiftUI

/// A full-width button: brass for opening a door, light for the main action, raised for a
/// second action, soft brass and danger for the rest.
struct FilledButtonStyle: ButtonStyle {
    enum Kind {
        case brass
        case light
        case raised
        case softBrass
        case danger
    }

    var kind: Kind
    var height: CGFloat = 52
    var radius: CGFloat = 14
    var expands = true

    func makeBody(configuration: Configuration) -> StyledLabel {
        StyledLabel(configuration: configuration, style: self)
    }

    struct StyledLabel: View {
        let configuration: Configuration
        let style: FilledButtonStyle
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: style.radius, style: .continuous)
            configuration.label
                .font(.body.weight(.semibold))
                .foregroundStyle(colors.foreground)
                .padding(.horizontal, style.expands ? 0 : 18)
                .frame(maxWidth: style.expands ? .infinity : nil, minHeight: style.height)
                .background(colors.background, in: shape)
                .overlay(shape.stroke(colors.border))
                .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
                .contentShape(shape)
        }

        private var colors: (foreground: Color, background: Color, border: Color) {
            switch style.kind {
            case .brass: return (Theme.onBrass, Theme.brass, .clear)
            case .light: return (Theme.background, Theme.text, .clear)
            case .raised: return (Theme.text, Theme.raised, Theme.raisedLine)
            case .softBrass: return (Theme.brass, Theme.brassSoft, Theme.brassLine)
            case .danger: return (Theme.alert, Theme.failed, Theme.failedLine)
            }
        }
    }
}

/// A round call control with its label below; light when it is on.
struct CallControl: View {
    let title: String
    let systemImage: String
    var active = false
    var size: CGFloat = 56
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.4))
                    .frame(width: size, height: size)
                    .foregroundStyle(active ? Theme.background : Theme.text)
                    .background(active ? Theme.text : Theme.raised, in: Circle())
                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

/// A capsule that filters a list; light when chosen.
struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .medium))
                .foregroundStyle(selected ? Theme.background : Theme.text)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(selected ? Theme.text : Theme.surface, in: Capsule())
                .overlay(Capsule().stroke(selected ? Color.clear : Theme.field))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A round icon button for toolbars and headers.
struct RoundIcon: View {
    let systemImage: String
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(Theme.text)
            .frame(width: size, height: size)
            .background(Theme.surface, in: Circle())
            .overlay(Circle().stroke(Theme.line))
    }
}
