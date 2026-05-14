//
//  SubscriptionManager.swift
//  MigraineIQ
//
//  StoreKit 2 entitlement manager. Singleton — access via `.shared`.
//
//  Lifecycle
//  ─────────────────────────────────────────────────────────────────────────
//  1. `init()` fires a detached Task that runs `listenForTransactionUpdates()`
//     indefinitely. This catches purchases made on other devices (Family
//     Sharing, promotion redemptions, etc.) and handles Ask to Buy approvals.
//  2. Call `refreshEntitlements()` from the app's `.task {}` on launch to
//     resolve current subscription state immediately.
//  3. `purchase(_:)` and `restorePurchases()` are the only write paths.
//
//  Pro tier
//  ─────────────────────────────────────────────────────────────────────────
//  Product IDs:
//    com.kieny.MigraineIQ.pro.monthly   ($6.99 / month, 7-day trial)
//    com.kieny.MigraineIQ.pro.annual    ($49.99 / year, 7-day trial)
//  Both belong to a single subscription group so only one can be active.
//

import Foundation
import StoreKit

@Observable
@MainActor
final class SubscriptionManager {

    // MARK: - Product IDs

    enum ProductID {
        static let monthly = "com.kieny.MigraineIQ.pro.monthly"
        static let annual  = "com.kieny.MigraineIQ.pro.annual"
        static let all: [String] = [monthly, annual]
    }

    // MARK: - Shared instance

    static let shared = SubscriptionManager()

    // MARK: - Published state

    /// `true` when the user has a verified, active Pro subscription.
    private(set) var isProSubscriber: Bool = false

    /// The two purchasable products, loaded from StoreKit.
    /// Empty until `loadProducts()` completes.
    private(set) var products: [Product] = []

    /// Set during a purchase or restore flow.
    private(set) var isPurchasing: Bool = false

    /// Populated if a purchase or restore fails.
    private(set) var purchaseError: String? = nil

    // MARK: - Init

    private init() {
        // Kick off the update listener immediately so no transaction
        // is missed between launch and the first refreshEntitlements() call.
        Task.detached(priority: .background) { [weak self] in
            await self?.listenForTransactionUpdates()
        }
    }

    // MARK: - Entitlement check

    /// Checks `Transaction.currentEntitlements` and updates `isProSubscriber`.
    /// Call once on app launch and after any purchase/restore.
    func refreshEntitlements() async {
        var hasActive = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if ProductID.all.contains(transaction.productID),
               transaction.revocationDate == nil {
                hasActive = true
            }
        }
        isProSubscriber = hasActive
    }

    // MARK: - Product loading

    /// Fetches product metadata from StoreKit (or the local .storekit config).
    /// Results are sorted annual first.
    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: ProductID.all)
            // Annual first so paywall renders it prominently.
            products = fetched.sorted {
                ($0.id == ProductID.annual ? 0 : 1) < ($1.id == ProductID.annual ? 0 : 1)
            }
        } catch {
            // Non-fatal — products array stays empty; paywall shows a retry.
        }
    }

    // MARK: - Purchase

    /// Initiates a purchase for `product`. Returns `true` on success.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isPurchasing   = true
        purchaseError  = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseError = "Purchase could not be verified. Please try again."
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                return true

            case .userCancelled:
                return false

            case .pending:
                // Ask to Buy — parent must approve.
                return false

            @unknown default:
                return false
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Restore

    /// Syncs any prior purchases from the App Store.
    func restorePurchases() async {
        isPurchasing  = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Update listener (runs for the app lifetime)

    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish()
            await refreshEntitlements()
        }
    }
}

// MARK: - Convenience

extension SubscriptionManager {

    /// Monthly product, if loaded.
    var monthlyProduct: Product? {
        products.first { $0.id == ProductID.monthly }
    }

    /// Annual product, if loaded.
    var annualProduct: Product? {
        products.first { $0.id == ProductID.annual }
    }

    /// Formatted display price for a product, e.g. "$7.99/month".
    func displayPrice(for product: Product) -> String {
        let period: String
        switch product.id {
        case ProductID.monthly: period = "/month"
        case ProductID.annual:  period = "/year"
        default:                period = ""
        }
        return "\(product.displayPrice)\(period)"
    }
}
