import SwiftUI

/// The Tapcard design system — a 1:1 port of the web app's `globals.css`
/// light theme (tapcard.tertiaryinfotech.com). The site is light-by-default
/// with a violet primary, coral accent and teal highlight; the app locks to
/// light so both surfaces look identical.
///
/// Hex values are the sRGB equivalents of the site's HSL custom properties.
enum Theme {
    // Neutrals — `--background` … `--input`
    static let background = Color(hex: "#FCFBFF")       // hsl(270 60% 99%)
    static let surface = Color(hex: "#FFFFFF")          // hsl(0 0% 100%)
    static let surface2 = Color(hex: "#F7F4FB")         // hsl(268 44% 97%)
    static let foreground = Color(hex: "#19112D")       // hsl(258 46% 12%)
    static let mutedForeground = Color(hex: "#655C7A")  // hsl(258 14% 42%)
    static let border = Color(hex: "#E4DDEE")           // hsl(264 32% 90%)

    // Brand — `--primary`, `--accent` (coral), `--highlight` (teal)
    static let primary = Color(hex: "#6A47F5")          // hsl(252 90% 62%)
    static let accent = Color(hex: "#F86E59")           // hsl(8 92% 66%)
    static let highlight = Color(hex: "#16B6A0")        // hsl(172 78% 40%)
    static let success = Color(hex: "#259D65")          // hsl(152 62% 38%)

    /// `.gradient-primary` — linear-gradient(100deg, primary, accent).
    static let gradientPrimary = LinearGradient(
        colors: [primary, accent],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// `--radius: 0.85rem` ≈ 14pt — the web's default corner radius.
    static let radius: CGFloat = 14
}

// ─── Reusable web-styled chrome ─────────────────────────────────────────────

/// The web `Surface` card: translucent white, hairline border, soft shadow.
struct SurfaceCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.surface.opacity(0.8),
                        in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .shadow(color: Theme.primary.opacity(0.10), radius: 24, y: 12)
    }
}

/// The web `variant="primary"` button: violet→coral gradient, white text,
/// violet glow shadow.
struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Theme.gradientPrimary,
                        in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .shadow(color: Theme.primary.opacity(configuration.isPressed ? 0.15 : 0.30),
                    radius: 14, y: 8)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

/// The web `variant="outline"` button: transparent on white, hairline border.
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(configuration.isPressed ? Theme.surface2 : Theme.surface,
                        in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

extension View {
    /// Wrap in a web-style `Surface` card.
    func surfaceCard() -> some View { modifier(SurfaceCard()) }

    /// The auth/landing page backdrop: light lavender with the site's
    /// top violet wash (`from-primary/10 via-transparent`).
    func tapcardBackground() -> some View {
        background(
            ZStack {
                Theme.background
                LinearGradient(colors: [Theme.primary.opacity(0.10), .clear, .clear],
                               startPoint: .top, endPoint: .bottom)
            }
            .ignoresSafeArea()
        )
    }
}

/// "Tapcard" wordmark in the site's `.gradient-text` style.
struct GradientText: View {
    let text: String
    var font: Font = .system(size: 40, weight: .bold, design: .rounded)

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(Theme.gradientPrimary)
    }
}
