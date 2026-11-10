import SwiftUI

struct CircleButton: View {
    let title: String
    let systemImage: String
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .regular))
                    .frame(width: 76, height: 76)
                    .foregroundStyle(active ? Color.black : Color.white)
                    .background(active ? Color.white : Palette.darkButton, in: Circle())
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
