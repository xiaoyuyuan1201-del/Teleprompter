import SwiftUI

struct TextSettingsView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @AppStorage("defaultPromptMargin") private var promptMargin = 24.0
    @AppStorage("defaultPromptApplyMarginToRecordScreen") private var applyMarginToRecordScreen = true
    @AppStorage("defaultPromptFontStyle") private var fontStyleRaw = PromptFontStyle.standard.rawValue
    @AppStorage("defaultPromptLineSpacing") private var lineSpacing = 0.0
    @AppStorage("defaultPromptUppercase") private var uppercase = false
    @AppStorage("defaultPromptMirrorHorizontal") private var mirrorHorizontal = false
    @AppStorage("defaultPromptMirrorVertical") private var mirrorVertical = false
    @AppStorage("defaultPromptShowCueIndicator") private var showCueIndicator = true
    @AppStorage("defaultPromptUseOpenDyslexicFont") private var useOpenDyslexicFont = false
    @AppStorage("defaultPromptUseLexendFont") private var useLexendFont = false

    @State private var showsPaywall = false

    private let sampleText = "Welcome to your teleprompter! [pause and smile] This is how your text will appear on the teleprompter screen."

    private var fontStyle: PromptFontStyle {
        PromptFontStyle(rawValue: fontStyleRaw) ?? .standard
    }

    var body: some View {
        Form {
            Section {
                previewBox
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                NavigationLink {
                    MarginsSettingsView(margin: $promptMargin)
                } label: {
                    Text("Margins")
                }

                Toggle("Apply margins to the record screen", isOn: $applyMarginToRecordScreen)
            }

            Section {
                NavigationLink {
                    FontStyleSettingsView(selection: $fontStyleRaw)
                } label: {
                    Text("Change Font")
                }
                .disabled(useOpenDyslexicFont || useLexendFont)
                .foregroundStyle((useOpenDyslexicFont || useLexendFont) ? .secondary : .primary)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Line Spacing")
                        Spacer()
                        Text("\(Int(lineSpacing))")
                            .foregroundStyle(Color.creatorViolet)
                            .monospacedDigit()
                    }
                    Slider(value: $lineSpacing, in: 0...20, step: 1)
                        .tint(.creatorViolet)
                }
                .padding(.vertical, 2)
            }

            Section {
                Toggle("Uppercase", isOn: $uppercase)

                Toggle(isOn: mirrorBinding($mirrorHorizontal)) {
                    Text("Mirror Horizontally")
                }
                .disabled(!purchaseManager.isPro)
                .foregroundStyle(purchaseManager.isPro ? .primary : .secondary)

                Toggle(isOn: mirrorBinding($mirrorVertical)) {
                    Text("Mirror Vertically")
                }
                .disabled(!purchaseManager.isPro)
                .foregroundStyle(purchaseManager.isPro ? .primary : .secondary)

                Toggle("Show Cue Indicator", isOn: $showCueIndicator)
            } footer: {
                if !purchaseManager.isPro {
                    Text("Mirroring is a Pro feature. Tap a mirror toggle to upgrade.")
                }
            }

            Section {
                Toggle("OpenDyslexic Font", isOn: Binding(
                    get: { useOpenDyslexicFont },
                    set: { newValue in
                        useOpenDyslexicFont = newValue
                        if newValue { useLexendFont = false }
                    }
                ))

                Toggle("Lexend Font", isOn: Binding(
                    get: { useLexendFont },
                    set: { newValue in
                        useLexendFont = newValue
                        if newValue { useOpenDyslexicFont = false }
                    }
                ))
            } header: {
                Text("Having trouble reading?")
            } footer: {
                Text("These use the closest built-in system typeface until dedicated font files are added to the app.")
            }
        }
        .navigationTitle("Text")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showsPaywall) {
            PaywallView(source: .inApp)
                .environmentObject(purchaseManager)
        }
    }

    private func mirrorBinding(_ storage: Binding<Bool>) -> Binding<Bool> {
        Binding(
            get: { storage.wrappedValue },
            set: { newValue in
                if purchaseManager.isPro {
                    storage.wrappedValue = newValue
                } else {
                    showsPaywall = true
                }
            }
        )
    }

    private var previewBox: some View {
        AutoScrollingTextView(
            text: sampleText,
            fontSize: 26,
            speed: 0,
            timingMode: .fixed,
            targetDuration: 60,
            horizontalPadding: CGFloat(promptMargin),
            isPlaying: false,
            resetToken: 0,
            topPadding: 20,
            lineSpacing: CGFloat(lineSpacing),
            uppercase: uppercase,
            fontStyle: fontStyle,
            useOpenDyslexicFont: useOpenDyslexicFont,
            useLexendFont: useLexendFont
        )
        .scaleEffect(x: mirrorHorizontal && purchaseManager.isPro ? -1 : 1, y: mirrorVertical && purchaseManager.isPro ? -1 : 1)
        .frame(height: 220)
        .background(Color.promptBlack)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct MarginsSettingsView: View {
    @Binding var margin: Double

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Side margins", systemImage: "arrow.left.and.right")
                        Spacer()
                        Text("\(Int(margin)) pt")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $margin, in: 16...76, step: 1)
                        .tint(.creatorViolet)
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Controls how much empty space is kept on the left and right of your script.")
            }
        }
        .navigationTitle("Margins")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FontStyleSettingsView: View {
    @Binding var selection: String

    var body: some View {
        Form {
            Section {
                ForEach(PromptFontStyle.allCases) { style in
                    Button {
                        selection = style.rawValue
                    } label: {
                        HStack {
                            Text(style.title)
                                .foregroundStyle(.primary)
                            Spacer()
                            if style.rawValue == selection {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.creatorViolet)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Change Font")
        .navigationBarTitleDisplayMode(.inline)
    }
}
