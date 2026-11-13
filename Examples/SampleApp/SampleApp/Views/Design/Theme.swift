import SwiftUI
import UIKit

/// Colors and type of the app: a dark ground, brass for ringing and opening, blue for status.
enum Theme {
    static let background = Color(rgb: 0x0F141B)
    static let callBackground = Color(rgb: 0x0B0F14)
    static let bar = Color(rgb: 0x121821)
    static let barLine = Color(rgb: 0x232D3A)
    static let surface = Color(rgb: 0x18202B)
    static let line = Color(rgb: 0x263140)
    static let field = Color(rgb: 0x2E3A4B)
    static let raised = Color(rgb: 0x222C3A)
    static let raisedLine = Color(rgb: 0x3D4B5F)
    static let picture = Color(rgb: 0x1C2633)
    static let pictureMark = Color(rgb: 0x43536A)
    static let text = Color(rgb: 0xF2F4F7)
    static let secondary = Color(rgb: 0xA9B4C2)
    static let brass = Color(rgb: 0xF0B24A)
    static let onBrass = Color(rgb: 0x1A1203)
    static let brassSoft = Color(rgb: 0x2A2213)
    static let brassLine = Color(rgb: 0x5A4520)
    static let info = Color(rgb: 0x6FB6F2)
    static let alert = Color(rgb: 0xFFB8AD)
    static let hangUp = Color(rgb: 0x4A2320)
    static let failed = Color(rgb: 0x2A1615)
    static let failedLine = Color(rgb: 0x5A2A26)
    static let overlay = Color(rgb: 0x0B0F14).opacity(0.78)

    static let displayFont = "BarlowSemiCondensed-SemiBold"
    static let displayMediumFont = "BarlowSemiCondensed-Medium"

    /// Navigation and tab bars in the app's colors, with large titles in the display face.
    @MainActor
    static func applyBarAppearance() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = UIColor(background)
        navigation.shadowColor = .clear
        navigation.titleTextAttributes = [
            .foregroundColor: UIColor(text),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
        ]
        let large = UIFont(name: displayFont, size: 36) ?? .systemFont(ofSize: 34, weight: .bold)
        navigation.largeTitleTextAttributes = [
            .foregroundColor: UIColor(text),
            .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large),
        ]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation

        let tabs = UITabBarAppearance()
        tabs.configureWithOpaqueBackground()
        tabs.backgroundColor = UIColor(bar)
        tabs.shadowColor = UIColor(barLine)
        for layout in [tabs.stackedLayoutAppearance, tabs.inlineLayoutAppearance, tabs.compactInlineLayoutAppearance] {
            layout.normal.iconColor = UIColor(secondary)
            layout.normal.titleTextAttributes = [.foregroundColor: UIColor(secondary)]
            layout.selected.iconColor = UIColor(brass)
            layout.selected.titleTextAttributes = [.foregroundColor: UIColor(brass)]
        }
        UITabBar.appearance().standardAppearance = tabs
        UITabBar.appearance().scrollEdgeAppearance = tabs
    }
}

extension Color {
    init(rgb: UInt32) {
        self.init(red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255)
    }
}

extension Font {
    /// The condensed display face for titles and names.
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom(Theme.displayFont, size: size, relativeTo: style)
    }

    /// The condensed display face at medium weight, for digits and entered numbers.
    static func displayMedium(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom(Theme.displayMediumFont, size: size, relativeTo: style)
    }
}
