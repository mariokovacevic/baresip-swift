import SwiftUI

struct DTMFPad: View {
    let send: (String) -> Void
    private let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["*", "0", "#"]]

    var body: some View {
        VStack(spacing: 14) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { digit in
                        Button(digit) { send(digit) }
                            .font(.system(size: 32, weight: .regular))
                            .foregroundStyle(.white)
                            .frame(width: 76, height: 76)
                            .background(Palette.darkButton, in: Circle())
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
