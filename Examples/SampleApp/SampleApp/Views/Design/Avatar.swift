import SwiftUI

struct Avatar: View {
    let initials: String
    var size: CGFloat = 44
    var corner: CGFloat?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner ?? size / 2, style: .continuous)
        Text(initials)
            .font(.display(size * 0.42))
            .foregroundStyle(Theme.text)
            .frame(width: size, height: size)
            .background(Theme.raised, in: shape)
            .overlay(shape.stroke(Theme.field))
            .accessibilityHidden(true)
    }
}

/// A picture from a door camera, or the placeholder figure when there is none.
struct CameraPicture: View {
    let image: UIImage?
    var caption: String?
    var markSize: CGFloat = 56

    var body: some View {
        ZStack {
            Theme.picture
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel("Picture from the door camera")
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person")
                        .font(.system(size: markSize, weight: .ultraLight))
                        .foregroundStyle(Theme.pictureMark)
                    if let caption {
                        Text(caption)
                            .font(.caption)
                            .foregroundStyle(Theme.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .clipped()
    }
}

struct StatusDot: View {
    let color: Color
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// The app's mark: a bell with a keyhole.
struct LogoMark: View {
    var size: CGFloat = 56

    var body: some View {
        Image("Logo")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: size * 0.62, height: size * 0.62)
            .foregroundStyle(Theme.onBrass)
            .frame(width: size, height: size)
            .background(Theme.brass, in: RoundedRectangle(cornerRadius: size * 0.29, style: .continuous))
            .accessibilityLabel("Zvono")
    }
}
