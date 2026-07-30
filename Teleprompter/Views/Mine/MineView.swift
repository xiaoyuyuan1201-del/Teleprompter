import StoreKit
import SwiftUI

struct MineView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    @State private var showsPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    AppHeaderRow(title: "Mine")

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 28) {
                            profileCard
                            planCard
                            settingsCard
                            supportCard
                            legalCard
                            aboutCard
                        }
                        .padding(.horizontal, AppLayout.screenHorizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 36)
                    }
                }
            }
            .hidesSystemNavigationBar()
        }
        .fullScreenCover(isPresented: $showsPaywall) {
            PaywallView(source: .inApp)
                .environmentObject(purchaseManager)
        }
    }

    private var profileCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .font(.appHero)
                .foregroundStyle(Color.creatorViolet)

            VStack(alignment: .leading, spacing: 4) {
                Text("Teleprompter")
                    .font(.appHeadline)
                Text(purchaseManager.isPro ? "Pro member" : "Free plan")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .contentCard(cornerRadius: 20)
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionEyebrow(title: "Current Plan: \(purchaseManager.isPro ? "Pro" : "Free")")

            VStack(spacing: 0) {
                if purchaseManager.isPro {
                    MineRow(title: "Teleprompter Pro", systemImage: "crown.fill", trailing: "Active", showsChevron: false)
                } else {
                    Button {
                        showsPaywall = true
                    } label: {
                        MineRow(title: "Upgrade to Pro", systemImage: "crown.fill")
                    }
                    .buttonStyle(.plain)

                    MineDivider()
                }

                Button {
                    Task { await purchaseManager.restorePurchases() }
                } label: {
                    MineRow(title: "Restore Purchase", systemImage: "arrow.clockwise", showsChevron: false)
                }
                .buttonStyle(.plain)
            }
            .contentCard(cornerRadius: 20)
        }
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionEyebrow(title: "Settings")

            VStack(spacing: 0) {
                NavigationLink {
                    PromptingSettingsView()
                        .environmentObject(purchaseManager)
                } label: {
                    MineRow(title: "Prompting", systemImage: "text.alignleft")
                }
                .buttonStyle(.plain)

                MineDivider()

                NavigationLink {
                    RecordingSettingsView()
                } label: {
                    MineRow(title: "Recording", systemImage: "video")
                }
                .buttonStyle(.plain)

                MineDivider()

                NavigationLink {
                    PrivacySettingsView()
                } label: {
                    MineRow(title: "Privacy", systemImage: "hand.raised")
                }
                .buttonStyle(.plain)
            }
            .contentCard(cornerRadius: 20)
        }
    }

    private var supportCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionEyebrow(title: "Support & Feedback")

            VStack(spacing: 0) {
                Link(destination: URL(string: "mailto:support@example.com")!) {
                    MineRow(title: "Feedback", systemImage: "bubble.left")
                }
                .buttonStyle(.plain)

                MineDivider()

                Button {
                    requestReview()
                } label: {
                    MineRow(title: "Love the app? Rate us!", systemImage: "star")
                }
                .buttonStyle(.plain)
            }
            .contentCard(cornerRadius: 20)
        }
    }

    private var legalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionEyebrow(title: "Legal & Privacy")

            VStack(spacing: 0) {
                NavigationLink {
                    LegalDocumentView(title: "Privacy Policy")
                } label: {
                    MineRow(title: "Privacy Policy", systemImage: "lock")
                }
                .buttonStyle(.plain)

                MineDivider()

                NavigationLink {
                    LegalDocumentView(title: "Terms of Use")
                } label: {
                    MineRow(title: "Terms of Use", systemImage: "doc.text")
                }
                .buttonStyle(.plain)
            }
            .contentCard(cornerRadius: 20)
        }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionEyebrow(title: "About")

            VStack(spacing: 0) {
                Button {
                    hasCompletedOnboarding = false
                } label: {
                    MineRow(title: "Replay Onboarding", systemImage: "sparkles.rectangle.stack", showsChevron: false)
                }
                .buttonStyle(.plain)

                MineDivider()

                MineRow(title: "App", systemImage: "app", trailing: "Teleprompter", showsChevron: false)

                MineDivider()

                MineRow(title: "Version", systemImage: "number", trailing: appVersion, showsChevron: false)
            }
            .contentCard(cornerRadius: 20)
        }
    }

    private func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        AppStore.requestReview(in: scene)
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private struct MineRow: View {
    let title: String
    let systemImage: String
    var trailing: String?
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.appSubheadline)
                .foregroundStyle(Color.creatorViolet)
                .frame(width: 22)

            Text(title)
                .font(.appBody)
                .foregroundStyle(.primary)

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.appSubheadline)
                    .foregroundStyle(Color.creatorViolet)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.appCaption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .contentShape(Rectangle())
    }
}

private struct MineDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 52)
    }
}
