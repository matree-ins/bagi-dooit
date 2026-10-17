import SwiftUI

/// Shared visual tokens for Bagi Dooit. Semantic assets also support dark appearance.
enum BagiTheme {
    static let primary = Color("BagiPrimary")
    static let background = Color("BagiBackground")
    static let surface = Color("BagiSurface")
    static let soft = Color("BagiSoft")
    static let ink = Color("BagiInk")
    static let muted = Color("BagiMuted")
    static let accent = Color("BagiAccent")
    static let border = Color("BagiBorder")
    static let action = Color("BagiAction")
    static let hero = Color("BagiHero")
    static let success = Color("BagiSuccess")
    static let danger = Color("BagiDanger")
    static let warning = Color("BagiWarning")
    // Physical paper in the receipt illustration intentionally stays white in either appearance.
    static let paper = Color.white
    static let paperInk = Color.black
    static let spacing: CGFloat = 20
    static let radius: CGFloat = 20
}
