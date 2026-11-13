import SwiftUI

/// Picks the system framework that shows calls: CallKit or LiveCommunicationKit.
struct CallScreenView: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenTitle(title: "Call screen")
                Card {
                    ForEach(Array(SystemCallScreen.allCases.enumerated()), id: \.element) { index, screen in
                        if index > 0 {
                            RowDivider()
                        }
                        row(screen)
                    }
                }
                Note(text: note)
            }
            .padding(16)
        }
        .titledScreen("Call screen")
    }

    private var note: String {
        if model.usesDirectCalls {
            return """
            The simulator shows no call screen, so calls go straight to the engine whichever is \
            chosen. Try both on an iPhone.
            """
        }
        if !SystemCallScreen.liveCommunicationKit.isAvailable {
            return "LiveCommunicationKit needs iOS 17.4 or later; this iPhone uses CallKit."
        }
        return """
        Both show rings and calls on the iPhone's call screen and in Recents. The engine restarts \
        with the new one when no call runs.
        """
    }

    private func row(_ screen: SystemCallScreen) -> some View {
        Button {
            model.callScreen = screen
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(screen.title)
                        .foregroundStyle(Theme.text)
                    Text(screen.detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary)
                }
                Spacer(minLength: 8)
                if model.callScreen == screen {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.brass)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!screen.isAvailable)
        .opacity(screen.isAvailable ? 1 : 0.4)
        .accessibilityAddTraits(model.callScreen == screen ? .isSelected : [])
        .accessibilityIdentifier("callScreen.\(screen.id)")
    }
}
