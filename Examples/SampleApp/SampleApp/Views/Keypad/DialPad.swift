import SwiftUI

/// Twelve round keys, with letters under the digits on the large pad.
struct DialPad: View {
    var keySize: CGFloat = 74
    var showsLetters = true
    let press: (String) -> Void

    private static let keys: [(digit: String, letters: String)] = [
        ("1", ""), ("2", "ABC"), ("3", "DEF"),
        ("4", "GHI"), ("5", "JKL"), ("6", "MNO"),
        ("7", "PQRS"), ("8", "TUV"), ("9", "WXYZ"),
        ("*", ""), ("0", "+"), ("#", ""),
    ]

    var body: some View {
        let columns = Array(repeating: GridItem(.fixed(keySize), spacing: keySize * 0.35), count: 3)
        LazyVGrid(columns: columns, spacing: keySize * 0.16) {
            ForEach(Self.keys, id: \.digit) { key in
                Button {
                    press(key.digit)
                } label: {
                    VStack(spacing: 0) {
                        Text(key.digit)
                            .font(.displayMedium(keySize * 0.4))
                        if showsLetters {
                            Text(key.letters)
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1.4)
                                .foregroundStyle(Theme.secondary)
                                .frame(minHeight: 12)
                        }
                    }
                    .foregroundStyle(Theme.text)
                    .frame(width: keySize, height: keySize)
                    .background(Theme.surface, in: Circle())
                    .overlay(Circle().stroke(Theme.line))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(key.digit)
            }
        }
    }
}
