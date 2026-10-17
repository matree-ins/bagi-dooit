import SwiftUI

struct BagiScreenStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(BagiTheme.background)
            .foregroundStyle(BagiTheme.ink)
            .tint(BagiTheme.primary)
    }
}

extension View {
    func bagiScreen() -> some View { modifier(BagiScreenStyle()) }
}
