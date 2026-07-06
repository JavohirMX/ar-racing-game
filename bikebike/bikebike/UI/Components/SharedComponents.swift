import SwiftUI

struct MenuButton: View {
    let color: Color
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.buttonTap()
            AudioManager.shared.playButtonTap()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                Text(title)
                    .font(GameTypography.buttonLabel(20))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .frame(minWidth: 260)
        }
        .buttonStyle(BeveledButtonStyle(color: color))
    }
}

struct OrangeCTAButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.buttonTap()
            AudioManager.shared.playButtonTap()
            action()
        } label: {
            Text(title)
                .font(GameTypography.buttonLabel(18))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(OrangeCTAButtonStyle())
    }
}

struct CreamPanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(GameColors.creamPanel)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            )
    }
}

struct LapStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 32) {
            Button {
                if value > range.lowerBound { value -= 1 }
            } label: {
                Text("−")
                    .font(GameTypography.title(28))
                    .foregroundStyle(GameColors.darkBrown)
            }
            .buttonStyle(.plain)

            Text("\(value)")
                .font(GameTypography.title(36))
                .foregroundStyle(GameColors.darkBrown)
                .frame(minWidth: 40)

            Button {
                if value < range.upperBound { value += 1 }
            } label: {
                Text("+")
                    .font(GameTypography.title(28))
                    .foregroundStyle(GameColors.darkBrown)
            }
            .buttonStyle(.plain)
        }
    }
}

struct TornPaperPanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            )
            .overlay(alignment: .top) {
                TornEdge()
                    .fill(Color.white)
                    .frame(height: 12)
                    .offset(y: -6)
            }
    }
}

private struct TornEdge: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = rect.width / 10
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        for i in 0...10 {
            let x = CGFloat(i) * step
            let y = i.isMultiple(of: 2) ? rect.minY : rect.maxY
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct PlayerSlotRow: View {
    let slot: LobbySlotPresentation

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(slot.driver.color)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 16))
                }

            VStack(alignment: .leading, spacing: 2) {
                if slot.isOccupied, let nickname = slot.nickname {
                    Text(nickname)
                        .font(GameTypography.body(14).weight(.bold))
                        .foregroundStyle(GameColors.darkBrown)
                    Text(slot.subtitle)
                        .font(GameTypography.body(12))
                        .foregroundStyle(GameColors.qrGreen)
                } else {
                    Text("Waiting for player...")
                        .font(GameTypography.body(14).weight(.semibold))
                        .foregroundStyle(GameColors.darkBrown.opacity(0.6))
                    Text(slot.subtitle)
                        .font(GameTypography.body(12))
                        .foregroundStyle(.gray)
                }
            }

            Spacer()

            if slot.isHost {
                Image(systemName: "crown.fill")
                    .foregroundStyle(GameColors.qrGreen)
            } else if !slot.isOccupied {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(slot.isOccupied ? slot.driver.color.opacity(0.15) : Color.gray.opacity(0.12))
        )
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let nickname: String
    let stars: Int
    let time: TimeInterval?

    private var badgeColor: Color {
        switch rank {
        case 1: GameColors.gold
        case 2: GameColors.silver
        default: GameColors.bronze
        }
    }

    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(badgeColor)
                    .frame(width: 32, height: 32)
                Text("\(rank)")
                    .font(GameTypography.body(14).weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 40)

            Text(nickname)
                .font(GameTypography.body(15).weight(.bold))
                .foregroundStyle(GameColors.darkBrown)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: index <= stars ? "star.fill" : "star")
                        .font(.system(size: 12))
                        .foregroundStyle(index <= stars ? GameColors.gold : .gray.opacity(0.4))
                }
            }
            .frame(width: 90)

            Text(formatTime(time))
                .font(GameTypography.lapCounter(14))
                .foregroundStyle(GameColors.darkBrown)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }

    private func formatTime(_ time: TimeInterval?) -> String {
        guard let time else { return "--:--:--" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let hundredths = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d:%02d", minutes, seconds, hundredths)
    }
}

struct QRViewfinder: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.25))
                .frame(width: 260, height: 260)

            VStack(spacing: 4) {
                Text("Scan the")
                Text("QR Code")
            }
            .font(GameTypography.buttonLabel(22))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)

            ZStack {
                CornerBracket(corner: .topLeft)
                    .frame(width: 260, height: 260)
                CornerBracket(corner: .topRight)
                    .frame(width: 260, height: 260)
                CornerBracket(corner: .bottomLeft)
                    .frame(width: 260, height: 260)
                CornerBracket(corner: .bottomRight)
                    .frame(width: 260, height: 260)
            }
        }
    }
}

private struct CornerBracket: View {
    enum Corner { case topLeft, topRight, bottomLeft, bottomRight }

    let corner: Corner
    private let length: CGFloat = 40
    private let thickness: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            Path { path in
                switch corner {
                case .topLeft:
                    path.move(to: CGPoint(x: 0, y: length))
                    path.addLine(to: .zero)
                    path.addLine(to: CGPoint(x: length, y: 0))
                case .topRight:
                    path.move(to: CGPoint(x: geo.size.width - length, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width, y: length))
                case .bottomLeft:
                    path.move(to: CGPoint(x: 0, y: geo.size.height - length))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    path.addLine(to: CGPoint(x: length, y: geo.size.height))
                case .bottomRight:
                    path.move(to: CGPoint(x: geo.size.width - length, y: geo.size.height))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height - length))
                }
            }
            .stroke(GameColors.qrGreen, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
        }
    }
}

struct VirtualJoystick: View {
    @Binding var steer: Float

    @State private var dragOffset: CGSize = .zero
    private let radius: CGFloat = 70

    var body: some View {
        ZStack {
            Circle()
                .fill(GameColors.hudOverlay)
                .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 2))
                .frame(width: radius * 2, height: radius * 2)

            Circle()
                .fill(Color.white)
                .frame(width: 56, height: 56)
                .offset(dragOffset)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let limited = limitOffset(value.translation)
                    dragOffset = limited
                    steer = Float(limited.width / radius)
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3)) {
                        dragOffset = .zero
                        steer = 0
                    }
                }
        )
    }

    private func limitOffset(_ translation: CGSize) -> CGSize {
        let dist = sqrt(translation.width * translation.width + translation.height * translation.height)
        guard dist > radius else { return translation }
        let scale = radius / dist
        return CGSize(width: translation.width * scale, height: translation.height * scale)
    }
}

struct HUDActionButton: View {
    let label: String
    let systemImage: String?
    let isPressed: Bool
    let action: () -> Void
    let onRelease: () -> Void

    init(
        _ label: String,
        systemImage: String? = nil,
        isPressed: Bool = false,
        action: @escaping () -> Void,
        onRelease: @escaping () -> Void = {}
    ) {
        self.label = label
        self.systemImage = systemImage
        self.isPressed = isPressed
        self.action = action
        self.onRelease = onRelease
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(GameColors.hudOverlay)
                .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 2))
                .frame(width: 80, height: 80)
                .scaleEffect(isPressed ? 0.95 : 1)

            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Text(label)
                    .font(GameTypography.hudLabel())
                    .foregroundStyle(.white)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in action() }
                .onEnded { _ in onRelease() }
        )
    }
}
