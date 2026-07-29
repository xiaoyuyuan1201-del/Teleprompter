import SwiftUI

struct MineView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("defaultPromptSpeed") private var defaultSpeed = 44.0
    @AppStorage("defaultPromptFontSize") private var defaultFontSize = 48.0
    @AppStorage("defaultCountdownEnabled") private var countdownEnabled = true
    @AppStorage("defaultPromptFocusNearLens") private var focusNearLens = true
    @AppStorage("defaultPromptMargin") private var promptMargin = 24.0
    @AppStorage("defaultPromptTimingMode") private var timingModeRaw = PromptScrollTimingMode.fixed.rawValue
    @AppStorage("defaultPromptTargetMinutes") private var targetMinutes = 2.0

    @State private var showsPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                proSection
                promptingSection
                supportSection
                aboutSection
            }
            .navigationTitle("Mine")
            .navigationBarTitleDisplayMode(.large)
        }
        .fullScreenCover(isPresented: $showsPaywall) {
            PaywallView(source: .inApp)
                .environmentObject(purchaseManager)
        }
    }

    private var profileSection: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 42, weight: .regular))
                    .foregroundStyle(Color.creatorViolet)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Teleprompter")
                        .font(.headline)
                    Text(purchaseManager.isPro ? "Pro member" : "Free plan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private var proSection: some View {
        Section {
            if purchaseManager.isPro {
                LabeledContent {
                    Text("Active")
                        .foregroundStyle(Color.creatorViolet)
                        .fontWeight(.semibold)
                } label: {
                    Label("Teleprompter Pro", systemImage: "crown.fill")
                        .foregroundStyle(Color.creatorViolet)
                }
            } else {
                Button {
                    showsPaywall = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "crown.fill")
                            .font(.title3)
                            .foregroundStyle(Color.creatorViolet)
                            .frame(width: 40, height: 40)
                            .background(Color.creatorViolet.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Upgrade to Pro")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text("AI polish, unlimited scripts and mirror mode")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Button("Restore Purchases") {
                Task {
                    await purchaseManager.restorePurchases()
                }
            }
        } header: {
            Text("Pro")
        }
    }

    private var promptingSection: some View {
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
        } header: {
            Text("Prompting")
        } footer: {
            Text("These defaults come from onboarding and remain adjustable from the recording screen.")
        }
    }

    private var supportSection: some View {
        Section("Help") {
            Button {
                hasCompletedOnboarding = false
            } label: {
                Label("Replay Onboarding", systemImage: "sparkles.rectangle.stack")
            }

            Link(destination: URL(string: "mailto:support@example.com")!) {
                Label("Contact Support", systemImage: "envelope")
            }

            Button { } label: {
                Label("Privacy Policy", systemImage: "hand.raised")
            }

            Button { } label: {
                Label("Terms of Use", systemImage: "doc.text")
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("App", value: "Teleprompter")
            LabeledContent("Version", value: appVersion)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
