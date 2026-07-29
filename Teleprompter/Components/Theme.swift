import SwiftUI

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
        ZStack {
            Color.appCanvas

            RadialGradient(
                colors: [Color.creatorViolet.opacity(0.14), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 360
            )

            RadialGradient(
                colors: [Color.creatorVioletLight.opacity(0.08), .clear],
                center: .bottomLeading,
                startRadius: 30,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

struct ContentCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.055), lineWidth: 0.75)
            }
    }
}

extension View {
    func contentCard(cornerRadius: CGFloat = 24) -> some View {
        modifier(ContentCardModifier(cornerRadius: cornerRadius))
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
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 42, height: 42)
        }
        .buttonStyle(.glass)
        .tint(tint)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct VioletGlassButtonLabel: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 9) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 52)
    }
}

struct SectionEyebrow: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }
}
