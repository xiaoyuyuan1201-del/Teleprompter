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

/// The app's full type scale. Every piece of UI text should use one of these —
/// keeping the count small is what makes the app's typography feel consistent.
extension Font {
    /// Full-screen hero numerals (e.g. the countdown).
    static let appHero = Font.system(size: 40, weight: .bold)
    /// Screen and section-level titles.
    static let appTitle = Font.system(size: 28, weight: .bold)
    /// In-content section headers (e.g. "My Scripts", "My Videos").
    static let appSectionTitle = Font.system(size: 24, weight: .bold)
    /// Primary emphasis: row titles, nav bars, prominent buttons.
    static let appHeadline = Font.system(size: 18, weight: .semibold)
    /// Secondary emphasis: sub-labels, compact buttons.
    static let appSubheadline = Font.system(size: 16, weight: .semibold)
    /// Paragraph and body copy.
    static let appBody = Font.system(size: 16, weight: .regular)
    /// Supporting text under a headline (empty states, plan notes).
    static let appSecondary = Font.system(size: 14, weight: .regular)
    /// Small, unemphasized labels.
    static let appCaption = Font.system(size: 12, weight: .regular)
    /// Small, emphasized labels (badges, stat values).
    static let appCaptionEmphasis = Font.system(size: 12, weight: .semibold)
    /// Tiny badge numerals.
    static let appMicro = Font.system(size: 10, weight: .bold)
}

struct AppBackground: View {
    var body: some View {
        Color.appCanvas
            .ignoresSafeArea()
    }
}

struct ContentCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 16

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
    func contentCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(ContentCardModifier(cornerRadius: cornerRadius))
    }
}

struct ToolPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var height: CGFloat = 44
    var horizontalPadding: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appSubheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: height)
            .background(
                Color.creatorViolet.opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.35),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ToolSecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = 42
    var horizontalPadding: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appSubheadline)
            .foregroundStyle(.primary)
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: height)
            .background(
                Color(uiColor: .tertiarySystemFill).opacity(configuration.isPressed ? 0.72 : 1),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.38), lineWidth: 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .font(.appSubheadline)
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
        .font(.appHeadline)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 48)
    }
}

extension View {
    /// Hides the system navigation bar entirely so a screen can render its own
    /// header row (see `AppHeaderRow`) instead of fighting the system title's
    /// layout and iOS 26's automatic "glass" toolbar-item chrome.
    func hidesSystemNavigationBar() -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
    }
}

/// A custom nav-bar replacement: a left-aligned 28pt title plus optional trailing
/// content, both in one row, inset by the app's standard screen margin.
struct AppHeaderRow<Trailing: View>: View {
    let title: String
    var onTitleTap: (() -> Void)?
    var tapCount: Int = 5
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.appTitle)
                .foregroundStyle(.primary)
                .contentShape(Rectangle())
                .onTapGesture(count: tapCount) { onTitleTap?() }

            Spacer(minLength: 8)

            trailing()
        }
        .padding(.horizontal, AppLayout.screenHorizontalPadding)
        .padding(.vertical, 8)
    }
}

extension AppHeaderRow where Trailing == EmptyView {
    init(title: String, onTitleTap: (() -> Void)? = nil, tapCount: Int = 5) {
        self.title = title
        self.onTitleTap = onTitleTap
        self.tapCount = tapCount
        self.trailing = { EmptyView() }
    }
}

/// A tiny live microphone-level indicator: bars that rise with a normalized
/// (0...1) input level, for confirming audio is actually being picked up.
struct AudioLevelMeter: View {
    let level: Float
    var barCount: Int = 4
    var tint: Color = .white

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(tint)
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .frame(height: 16, alignment: .bottom)
        .animation(.easeOut(duration: 0.1), value: level)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let step = Float(index + 1) / Float(barCount)
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 16
        guard level > 0 else { return minHeight }
        if level >= step {
            return maxHeight
        }
        let ratio = CGFloat(level / step)
        return minHeight + (maxHeight - minHeight) * ratio
    }
}

struct StatPill: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.appCaptionEmphasis)
            .foregroundStyle(Color.creatorViolet)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Color.creatorViolet.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SectionEyebrow: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.appCaptionEmphasis)
            .tracking(1)
            .foregroundStyle(.secondary)
    }
}
