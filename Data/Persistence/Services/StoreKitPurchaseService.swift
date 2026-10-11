//
//  StoreKitPurchaseService.swift
//  BlueHour
//
//  StoreKit 2 기반 구매 서비스. 비소모성 상품 1개(평생 이용권)만 다루며 가족 공유는 쓰지 않는다.
//  구매 여부는 Transaction.currentEntitlements로 확인하고, Transaction.updates를 흘려보낸다. (R-GPTAFT)
//

import Foundation
import StoreKit

actor StoreKitPurchaseService: PurchaseServiceProtocol {

    /// 번들 ID 기준 평생 이용권 상품 ID.
    static let lifetimeProductID = "academy.credo.BlueHour.lifetime"

    private let productID: String
    private var cachedProduct: Product?

    init(productID: String = StoreKitPurchaseService.lifetimeProductID) {
        self.productID = productID
    }

    private func loadProduct() async throws -> Product? {
        if let cachedProduct { return cachedProduct }
        let products = try await Product.products(for: [productID])
        cachedProduct = products.first
        return cachedProduct
    }

    func product() async throws -> StoreProductInfo? {
        guard let product = try await loadProduct() else { return nil }
        return StoreProductInfo(displayPrice: product.displayPrice)
    }

    func purchase() async throws -> PurchaseOutcome {
        guard let product = try await loadProduct() else { return .cancelled }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await transaction.finish()
                return .success
            }
            return .cancelled
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func restore() async throws -> Bool {
        try await AppStore.sync()
        return await currentlyUnlocked()
    }

    func currentlyUnlocked() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productID,
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }

    nonisolated func transactionUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                for await update in Transaction.updates {
                    if case .verified(let transaction) = update {
                        await transaction.finish()
                        continuation.yield(())
                    }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
