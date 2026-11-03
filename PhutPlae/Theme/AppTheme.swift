import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.09, green: 0.07, blue: 0.08)
    static let card = Color(red: 0.16, green: 0.13, blue: 0.12)
    static let cardStroke = Color.white.opacity(0.08)
    static let saffron = Color(red: 0.91, green: 0.45, blue: 0.22)
    static let gold = Color(red: 0.93, green: 0.78, blue: 0.45)
    static let textPrimary = Color(red: 0.98, green: 0.95, blue: 0.90)
    static let textSecondary = Color(red: 0.78, green: 0.72, blue: 0.66)
    static let danger = Color(red: 0.86, green: 0.28, blue: 0.24)
    static let ok = Color(red: 0.45, green: 0.72, blue: 0.48)
}

struct CardSurface<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        )
    }
}
