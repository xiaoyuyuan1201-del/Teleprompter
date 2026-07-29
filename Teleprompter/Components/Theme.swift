import SwiftUI

enum AppLayout {
    static let screenHorizontalPadding: CGFloat = 20
}

extension Color {
    static let creatorViolet = Color(red: 108 / 255, green: 92 / 255, blue: 231 / 255)
    static let creatorVioletLight = Color(red: 168 / 255, green: 156 / 255, blue: 255 / 255)
    static let promptBlack = Color(red: 10 / 255, green: 10 / 255, blue: 14 / 255)

    static let appCanvas = Color(uiColor: .systemGroupedBackground)
    static let appSurface = Color(uiColor: .secondarySystemGroupedBackground)
    static let appInk = Color.primary
}

struct AppBackground: View {
    var body: some View {
        Color.appCanvas
            .ignoresSafeArea()
    }
}

struct ContentCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .background(
                Color.appSurface,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.42), lineWidth: 0.5)
            }
    }
}

extension View {
    func contentCard(cornerRadius: CGFloat = 10) -> some View {
        modifier(ContentCardModifier(cornerRadius: cornerRadius))
    }
}

struct ToolPrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 44
    var horizontalPadding: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: height)
            .background(
                Color.creatorViolet.opacity(configuration.isPressed ? 0.78 : 1),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

struct ToolSecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = 42
    var horizontalPadding: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: height)
            .background(
                Color(uiColor: .tertiarySystemFill).opacity(configuration.isPressed ? 0.72 : 1),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.38), lineWidth: 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

struct GlassIconButton: View {
    let systemName: String
    var tint: Color = .primary
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 38, height: 38)
        }
        .buttonStyle(ToolSecondaryButtonStyle(height: 38, horizontalPadding: 0))
        .tint(tint)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct VioletGlassButtonLabel: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 48)
    }
}

struct SectionEyebrow: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(0.65)
            .foregroundStyle(.secondary)
    }
}
