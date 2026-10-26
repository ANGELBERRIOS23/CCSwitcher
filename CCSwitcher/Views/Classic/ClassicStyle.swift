import SwiftUI

/// Colors the 1.x interface used that 2.0 changed. The Classic panel style
/// keeps them so it looks the way 1.12 did; everything else it needs
/// (`AppStyle`, `.cardFill`, `.textSecondary`, …) is still shared.
enum Classic {
    /// The 1.x brand orange (#E86D45). 2.0 moved `Color.brand` to Claude terracotta.
    static let brand = Color(red: 0xE8 / 255.0, green: 0x6D / 255.0, blue: 0x45 / 255.0)
    /// Subtle brand tint for the promo banner, from the 1.x brand orange.
    static let subtleBrand = Color.adaptive(light: brand.opacity(0.12), dark: brand.opacity(0.28))

    // 1.x used the system `.tertiary` / `.quaternary` styles here. Those blend
    // with whatever is behind them, and on the floating panel's glass they
    // come out near black. These fixed colors match what they looked like in
    // the 1.x NSPopover, measured from the README screenshots.
    /// 1.x `.tertiary`: e.g. the name of a model that was used today.
    static let tertiaryText = Color.adaptive(light: .black.opacity(0.25), dark: .white.opacity(0.36))
    /// 1.x `.quaternary`: e.g. a model with no requests today.
    static let quaternaryText = Color.adaptive(light: .black.opacity(0.10), dark: .white.opacity(0.20))
}

/// The 1.x capsule badge: white text on a solid color.
struct ClassicBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, AppStyle.badgeHPadding)
            .padding(.vertical, AppStyle.badgeVPadding)
            .background(color, in: Capsule())
    }
}
