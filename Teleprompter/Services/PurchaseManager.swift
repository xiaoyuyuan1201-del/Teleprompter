import Combine
import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let monthlyID = "com.yourcompany.teleprompter.pro.monthly"
    static let yearlyID = "com.yourcompany.teleprompter.pro.yearly"

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = observeTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func product(for plan: SubscriptionPlan) -> Product? {
        products.first { $0.id == plan.productID }
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await Product.products(for: [Self.monthlyID, Self.yearlyID])
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            errorMessage = "Unable to load subscription options."
        }
    }

    func purchase(plan: SubscriptionPlan) async -> Bool {
        guard let product = product(for: plan) else {
            errorMessage = "This subscription is not configured yet. Add the product IDs in App Store Connect."
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return isPro
            case .pending, .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = "Purchase could not be completed."
            return false
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            errorMessage = "Purchases could not be restored."
        }
    }

    func refreshEntitlements() async {
        var active = false

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try verified(result)
                if [Self.monthlyID, Self.yearlyID].contains(transaction.productID),
                   transaction.revocationDate == nil {
                    active = true
                }
            } catch {
                continue
            }
        }

        isPro = active
    }

    private func observeTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.verified(result)
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    continue
                }
            }
        }
    }

    nonisolated private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw PurchaseError.failedVerification
        }
    }
}

enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case yearly
    case monthly

    var id: String { rawValue }

    var productID: String {
        switch self {
        case .monthly: PurchaseManager.monthlyID
        case .yearly: PurchaseManager.yearlyID
        }
    }

    var title: String {
        switch self {
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    var fallbackPriceAmount: String {
        switch self {
        case .monthly: "¥38"
        case .yearly: "¥168"
        }
    }

    var fallbackPrice: String {
        switch self {
        case .monthly: fallbackPriceAmount + " / month"
        case .yearly: fallbackPriceAmount + " / year"
        }
    }

    var note: String {
        switch self {
        case .monthly: "Flexible access"
        case .yearly: "Best value · Save 63%"
        }
    }
}

enum PurchaseError: Error {
    case failedVerification
}
