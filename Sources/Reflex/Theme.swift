import SwiftUI
import UIKit

enum RTheme {
    // MARK: - Colors
    static let bg         = Color(uiColor: .systemGroupedBackground)
    static let surface    = Color(uiColor: .secondarySystemGroupedBackground)
    static let elevated   = Color(uiColor: .systemBackground)
    static let accent     = Color(uiColor: .systemBlue)
    static let accentDim  = Color(uiColor: .systemBlue).opacity(0.22)
    static let white      = Color(uiColor: .label)
    static let muted      = Color(uiColor: .secondaryLabel)
    static let faint      = Color(uiColor: .tertiaryLabel).opacity(0.55)
    static let red        = Color(uiColor: .systemRed)
    static let green      = Color(uiColor: .systemGreen)
    static let orange     = Color(uiColor: .systemOrange)
    static let purple     = Color(uiColor: .systemPurple)
    static let teal       = Color(uiColor: .systemTeal)
    static let darkSignal = Color(red: 0.05, green: 0.06, blue: 0.08)

    // MARK: - Typography helpers
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func serif(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func rounded(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    // MARK: - Spacing
    static let pad: CGFloat = 20
    static let padSm: CGFloat = 16
    static let radius: CGFloat = 12
    static let radiusSm: CGFloat = 10

    static func playSelectionHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Reusable components

struct PrimaryButton: View {
    let label: String
    let action: () -> Void
    var fullWidth: Bool = false

    var body: some View {
        Button {
            RTheme.playSelectionHaptic()
            action()
        } label: {
            Text(label)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .frame(minHeight: 50)
                .padding(.horizontal, fullWidth ? 0 : 22)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: RTheme.radius))
        .controlSize(.large)
        .tint(RTheme.accent)
    }
}

struct SurfaceCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(RTheme.pad)
            .background(RTheme.elevated)
            .clipShape(RoundedRectangle(cornerRadius: RTheme.radius, style: .continuous))
    }
}
