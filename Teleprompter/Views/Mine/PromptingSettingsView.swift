import SwiftUI

struct PromptingSettingsView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @AppStorage("defaultPromptSpeed") private var defaultSpeed = 44.0
    @AppStorage("defaultPromptFontSize") private var defaultFontSize = 48.0
    @AppStorage("defaultCountdownEnabled") private var countdownEnabled = true
    @AppStorage("defaultPromptFocusNearLens") private var focusNearLens = true
    @AppStorage("defaultPromptMargin") private var promptMargin = 24.0
    @AppStorage("defaultPromptApplyMarginToRecordScreen") private var applyMarginToRecordScreen = true
    @AppStorage("defaultPromptTimingMode") private var timingModeRaw = PromptScrollTimingMode.fixed.rawValue
    @AppStorage("defaultPromptTargetMinutes") private var targetMinutes = 2.0
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
        VStack(spacing: 0) {
            previewBox
                .padding(.horizontal, AppLayout.screenHorizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Color.appCanvas)

            Divider()

            Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Default speed", systemImage: "speedometer")
                        Spacer()
                        Text("\(Int(defaultSpeed))")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $defaultSpeed, in: 22...82, step: 1)
                        .tint(.creatorViolet)
                }
                .padding(.vertical, 4)

                Picker("Default timing", selection: Binding(
                    get: { PromptScrollTimingMode(rawValue: timingModeRaw) ?? .fixed },
                    set: { timingModeRaw = $0.rawValue }
                )) {
                    ForEach(PromptScrollTimingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                if timingModeRaw == PromptScrollTimingMode.timed.rawValue {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Target duration", systemImage: "timer")
                            Spacer()
                            Text(targetMinutes < 1 ? "30 sec" : String(format: "%.1f min", targetMinutes))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $targetMinutes, in: 0.5...10, step: 0.5)
                            .tint(.creatorViolet)
                    }
                    .padding(.vertical, 4)
                }

                Toggle(isOn: $countdownEnabled) {
                    Label("3-second countdown", systemImage: "timer")
                }
            } header: {
                Text("Speed & Timing")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Default text size", systemImage: "textformat.size")
                        Spacer()
                        Text("\(Int(defaultFontSize)) pt")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $defaultFontSize, in: 32...72, step: 1)
                        .tint(.creatorViolet)
                }
                .padding(.vertical, 4)

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

                Toggle("Uppercase", isOn: $uppercase)
            } header: {
                Text("Text")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Side margins", systemImage: "arrow.left.and.right")
                        Spacer()
                        Text("\(Int(promptMargin)) pt")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $promptMargin, in: 16...76, step: 1)
                        .tint(.creatorViolet)
                }
                .padding(.vertical, 4)

                Toggle("Apply margins to the record screen", isOn: $applyMarginToRecordScreen)

                Toggle(isOn: $focusNearLens) {
                    Label("Keep text near the lens", systemImage: "camera.metering.center.weighted")
                }

                Toggle("Show Cue Indicator", isOn: $showCueIndicator)

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

                LabeledContent("Recording quality", value: "1080p")
            } header: {
                Text("Layout")
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
                Text("These use the closest built-in system typeface until dedicated font files are added to the app. These defaults remain adjustable from the recording screen.")
            }
            }
        }
        .navigationTitle("Prompting")
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
            fontSize: CGFloat(min(defaultFontSize, 32)),
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
