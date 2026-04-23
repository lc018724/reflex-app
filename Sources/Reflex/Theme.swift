import SwiftUI

enum RTheme {
    // MARK: - Colors
    static let bg         = Color(red: 0.05, green: 0.05, blue: 0.07)
    static let surface    = Color(red: 0.10, green: 0.10, blue: 0.13)
    static let gold       = Color(red: 0.84, green: 0.65, blue: 0.37)
    static let goldDim    = Color(red: 0.84, green: 0.65, blue: 0.37).opacity(0.35)
    static let white      = Color.white
    static let muted      = Color.white.opacity(0.40)
    static let faint      = Color.white.opacity(0.18)
    static let red        = Color(red: 0.95, green: 0.30, blue: 0.30)
    static let green      = Color(red: 0.30, green: 0.90, blue: 0.55)

    // MARK: - Typography helpers
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func serif(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func rounded(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // MARK: - Spacing
    static let pad: CGFloat = 24
    static let padSm: CGFloat = 16
    static let radius: CGFloat = 18
    static let radiusSm: CGFloat = 12
}

// MARK: - Reusable components

struct GoldButton: View {
    let label: String
    let action: () -> Void
    var fullWidth: Bool = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(RTheme.rounded(17, weight: .bold))
                .tracking(3)
                .foregroundStyle(RTheme.bg)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .frame(height: 56)
                .padding(.horizontal, fullWidth ? 0 : 40)
                .background(RTheme.gold)
                .clipShape(RoundedRectangle(cornerRadius: RTheme.radius))
        }
    }
}

struct SurfaceCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(RTheme.pad)
            .background(RTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: RTheme.radius))
    }
}
