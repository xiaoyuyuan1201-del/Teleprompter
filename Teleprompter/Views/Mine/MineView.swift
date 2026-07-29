import SwiftUI

struct MineView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

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
                            .background(Color.creatorViolet.opacity(0.11), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

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
            NavigationLink {
                PromptingSettingsView()
                    .environmentObject(purchaseManager)
            } label: {
                Label("Prompting", systemImage: "text.alignleft")
            }
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
