import SwiftUI

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.buttonTap()
            action()
        }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(GameColors.darkBrown)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(GameColors.creamButton)
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                )
        }
        .buttonStyle(.plain)
    }
}

struct SettingsGearButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.buttonTap()
            action()
        }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(GameColors.darkBrown)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(GameColors.creamButton)
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                )
        }
        .buttonStyle(.plain)
    }
}

struct ScreenTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(GameTypography.screenTitle())
            .foregroundStyle(GameColors.titleWhite)
            .gameTitleShadow()
    }
}

struct ScenicBackground: View {
    var imageName: String = "MainMenuBackground"

    var body: some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .ignoresSafeArea()
    }
}

struct ScreenChrome<Content: View>: View {
    let title: String
    let onBack: () -> Void
    var backgroundImage: String = "MainMenuBackground"
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            ScenicBackground(imageName: backgroundImage)
            VStack(spacing: 0) {
                HStack {
                    BackButton(action: onBack)
                    Spacer()
                    ScreenTitle(text: title)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                content()
            }
        }
    }
}
