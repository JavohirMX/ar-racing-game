import SwiftUI

enum GameTypography {
    static func title(_ size: CGFloat = 36) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    static func screenTitle(_ size: CGFloat = 32) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func buttonLabel(_ size: CGFloat = 18) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    static func hudLabel(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func countdown(_ size: CGFloat = 64) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    static func lapCounter(_ size: CGFloat = 18) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
}

struct TitleShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: GameColors.darkBrown.opacity(0.6), radius: 0, x: 2, y: 3)
            .shadow(color: GameColors.darkBrown.opacity(0.3), radius: 4, x: 0, y: 4)
    }
}

extension View {
    func gameTitleShadow() -> some View {
        modifier(TitleShadowModifier())
    }
}
