import SwiftUI

enum SceneZeroTheme {
    static let background = Color(.systemGroupedBackground)
    static let secondaryBackground = Color(.secondarySystemGroupedBackground)
    static let cardBackground = Color(.systemBackground)
    static let elevatedBackground = Color(.tertiarySystemGroupedBackground)
    static let separator = Color(.separator)

    static let accent = Color(red: 0.31, green: 0.52, blue: 0.36)
    static let accentSoft = Color(red: 0.83, green: 0.90, blue: 0.78)
    static let infoAccent = Color(red: 0.31, green: 0.27, blue: 0.90)
    static let infoAccentSoft = Color(red: 0.90, green: 0.90, blue: 1.00)
    static let promptAccent = infoAccent

    static let floatingForeground = Color.white

    static func groupedBackground() -> some View {
        background.ignoresSafeArea()
    }
}
