import StoreKit
import SwiftUI

struct MineView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @State private var showsPaywall = false
    @State private var showsManageSubscriptions = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    AppHeaderRow(title: "Settings")

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            planCard
                            supportCard
                            legalCard
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
        .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            MineGroupLabel(title: "Current plan: \(purchaseManager.isPro ? "Pro" : "Free")")

            VStack(spacing: 0) {
                Button {
                    if purchaseManager.isPro {
                        showsManageSubscriptions = true
                    } else {
                        showsPaywall = true
                    }
                } label: {
                    MineRow(title: "Manage my plan", systemImage: "diamond")
                }
                .buttonStyle(.plain)

                MineDivider()

                Button {
                    Task { await purchaseManager.restorePurchases() }
                } label: {
                    MineRow(title: "Restore purchase", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
            }
            .contentCard(cornerRadius: 20)
        }
    }

    private var supportCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            MineGroupLabel(title: "Support & feedback")

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
            MineGroupLabel(title: "Legal & privacy")

            VStack(spacing: 0) {
                NavigationLink {
                    LegalDocumentView(title: "Privacy Policy")
                } label: {
                    MineRow(title: "Privacy policy", systemImage: "lock")
                }
                .buttonStyle(.plain)

                MineDivider()

                NavigationLink {
                    LegalDocumentView(title: "Disclaimer")
                } label: {
                    MineRow(title: "Disclaimer", systemImage: "doc.text")
                }
                .buttonStyle(.plain)
            }
            .contentCard(cornerRadius: 20)
        }
    }

    private func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        AppStore.requestReview(in: scene)
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
                .foregroundStyle(.primary)
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

private struct MineGroupLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.appCaptionEmphasis)
            .foregroundStyle(.secondary)
    }
}
