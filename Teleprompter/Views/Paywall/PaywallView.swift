import SwiftUI

struct PaywallView: View {
    enum Source {
        case onboarding
        case inApp

        var analyticsValue: String {
            switch self {
            case .onboarding: "onboarding"
            case .inApp: "in_app"
            }
        }
    }

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: SubscriptionPlan = .yearly

    let source: Source
    var onClose: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        hero
                        benefits
                        plans
                        trialDisclosure
                        legalCopy
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 168)
                }
            }
            .navigationTitle("Teleprompter Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close paywall")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Restore") {
                        Task { await purchaseManager.restorePurchases() }
                    }
                    .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                purchaseArea
            }
        }
        .onAppear {
            AppAnalytics.track("iap_show", metadata: ["source": source.analyticsValue])
        }
        .alert("Teleprompter", isPresented: Binding(
            get: { purchaseManager.errorMessage != nil },
            set: { if !$0 { purchaseManager.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                purchaseManager.errorMessage = nil
            }
        } message: {
            Text(purchaseManager.errorMessage ?? "")
        }
    }

    private var hero: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.creatorViolet.opacity(0.12))
                    .frame(width: 132, height: 132)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.creatorViolet, .creatorVioletLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 94, height: 94)
                    .shadow(color: Color.creatorViolet.opacity(0.28), radius: 24, y: 14)

                Image(systemName: "crown.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 9) {
                Text("Try every Pro tool free")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("Start with a 3-day trial, then keep Pro only if it helps your recordings.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 14)
            }
        }
        .padding(.top, 8)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionEyebrow(title: "Included with Pro")

            BenefitRow(
                icon: "sparkles",
                title: "AI script polish",
                detail: "Improve grammar, make speech more natural, or shorten a script."
            )
            BenefitRow(
                icon: "doc.on.doc.fill",
                title: "Unlimited scripts",
                detail: "Keep multiple drafts and switch between every project."
            )
            BenefitRow(
                icon: "rectangle.on.rectangle.angled",
                title: "Mirror mode",
                detail: "Use professional beam-splitter teleprompter rigs."
            )
            BenefitRow(
                icon: "pause.circle.fill",
                title: "Advanced recording",
                detail: "Pause and resume takes without losing your recording."
            )
        }
        .padding(20)
        .contentCard(cornerRadius: 12)
    }

    private var plans: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow(title: "Choose a plan")
                .padding(.leading, 4)

            ForEach(SubscriptionPlan.allCases) { plan in
                PlanCard(
                    plan: plan,
                    price: price(for: plan),
                    isSelected: selectedPlan == plan
                ) {
                    withAnimation(.snappy) {
                        selectedPlan = plan
                    }
                }
            }
        }
    }

    private var trialDisclosure: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Trial timeline")
                    .font(.headline)
                Spacer()
                Text("3 DAYS FREE")
                    .font(.caption2.bold())
                    .tracking(0.5)
                    .foregroundStyle(Color.creatorViolet)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.creatorViolet.opacity(0.11), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            }

            DisclosureRow(title: "Today", value: "¥0")
            DisclosureRow(title: "Trial ends", value: trialEndDateText)
            DisclosureRow(title: "Then renews", value: renewalText)

            Text("The App Store confirms your exact offer before purchase. Trial eligibility can vary by Apple ID. Cancel at least 24 hours before renewal to avoid being charged.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
        }
        .padding(18)
        .contentCard(cornerRadius: 12)
    }

    private var purchaseArea: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    let success = await purchaseManager.purchase(plan: selectedPlan)
                    if success {
                        close()
                    }
                }
            } label: {
                VioletGlassButtonLabel(
                    title: purchaseManager.isLoading ? "Please wait..." : "Start 3-day free trial",
                    systemImage: purchaseManager.isLoading ? nil : "arrow.right"
                )
                .overlay(alignment: .leading) {
                    if purchaseManager.isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding(.leading, 18)
                    }
                }
            }
            .buttonStyle(ToolPrimaryButtonStyle())
            .tint(.creatorViolet)
            .disabled(purchaseManager.isLoading)

            Text("\(renewalText) after the trial · auto-renews · cancel anytime")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Restore previous purchase") {
                Task { await purchaseManager.restorePurchases() }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.creatorViolet)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var legalCopy: some View {
        VStack(spacing: 12) {
            Text("Payment is charged to your Apple ID after any eligible trial. Subscriptions renew automatically unless cancelled in App Store settings.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            HStack(spacing: 20) {
                Button("Terms") { }
                Button("Privacy") { }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
    }

    private var trialEndDateText: String {
        let date = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var renewalText: String {
        let unit = selectedPlan == .yearly ? "year" : "month"
        return "\(price(for: selectedPlan)) / \(unit)"
    }

    private func price(for plan: SubscriptionPlan) -> String {
        purchaseManager.product(for: plan)?.displayPrice ?? plan.fallbackPriceAmount
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}

private struct DisclosureRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }
}

private struct PlanCard: View {
    let plan: SubscriptionPlan
    let price: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.creatorViolet : Color.secondary.opacity(0.55))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(.headline)

                        if plan == .yearly {
                            Text("BEST VALUE")
                                .font(.caption2.bold())
                                .foregroundStyle(Color.creatorViolet)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.creatorViolet.opacity(0.12), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }
                    }

                    Text(plan.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(price)
                    .font(.headline)
                    .multilineTextAlignment(.trailing)
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                isSelected ? Color.creatorViolet.opacity(0.09) : Color.appSurface,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isSelected ? Color.creatorViolet : Color.primary.opacity(0.055),
                        lineWidth: isSelected ? 1.5 : 0.75
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

private struct BenefitRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.creatorViolet)
                .frame(width: 38, height: 38)
                .background(Color.creatorViolet.opacity(0.11), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }
}
