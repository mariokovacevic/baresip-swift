import SwiftUI

struct Avatar: View {
    let initials: String
    var size: CGFloat = 40
    var tint: Color = Palette.secondaryText
    var background: Color = Color(.systemGray6)

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(background, in: Circle())
            .accessibilityHidden(true)
    }
}
