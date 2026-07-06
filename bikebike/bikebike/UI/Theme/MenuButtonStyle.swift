import SwiftUI

struct BeveledButtonStyle: ButtonStyle {
    let baseColor: Color
    let depthColor: Color?

    init(color: Color) {
        self.baseColor = color
        self.depthColor = color.opacity(0.75)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(depthColor ?? baseColor.opacity(0.75))
                        .offset(y: configuration.isPressed ? 1 : 4)
                    RoundedRectangle(cornerRadius: 20)
                        .fill(baseColor)
                        .offset(y: configuration.isPressed ? 2 : 0)
                }
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct OrangeCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 14)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(GameColors.primaryOrange)
                    .shadow(color: GameColors.primaryOrange.opacity(0.5), radius: configuration.isPressed ? 2 : 6, y: 4)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
