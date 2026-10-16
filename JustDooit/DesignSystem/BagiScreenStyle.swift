import SwiftUI

struct BagiScreenStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(BagiTheme.background)
            .tint(BagiTheme.primary)
    }
}

extension View {
    func bagiScreen() -> some View { modifier(BagiScreenStyle()) }
}
