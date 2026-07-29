import SwiftUI

struct PromptingSettingsView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @AppStorage("defaultPromptSpeed") private var defaultSpeed = 44.0
    @AppStorage("defaultPromptFontSize") private var defaultFontSize = 48.0
    @AppStorage("defaultCountdownEnabled") private var countdownEnabled = true
    @AppStorage("defaultPromptFocusNearLens") private var focusNearLens = true
    @AppStorage("defaultPromptMargin") private var promptMargin = 24.0
    @AppStorage("defaultPromptTimingMode") private var timingModeRaw = PromptScrollTimingMode.fixed.rawValue
    @AppStorage("defaultPromptTargetMinutes") private var targetMinutes = 2.0

    var body: some View {
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

                Toggle(isOn: $countdownEnabled) {
                    Label("3-second countdown", systemImage: "timer")
                }

                Toggle(isOn: $focusNearLens) {
                    Label("Keep text near the lens", systemImage: "camera.metering.center.weighted")
                }

                LabeledContent("Recording quality", value: "1080p")

                NavigationLink {
                    TextSettingsView()
                        .environmentObject(purchaseManager)
                } label: {
                    Label("Text", systemImage: "textformat")
                }
            } footer: {
                Text("These defaults come from onboarding and remain adjustable from the recording screen.")
            }
        }
        .navigationTitle("Prompting")
        .navigationBarTitleDisplayMode(.inline)
    }
}
