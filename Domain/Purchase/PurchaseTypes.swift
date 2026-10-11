//
//  PurchaseTypes.swift
//  BlueHour
//
//  구매(StoreKit 2)를 감싸는 추상화. StoreKit 타입을 바깥으로 노출하지 않아
//  구매 로직을 Fake로 대체해 테스트할 수 있다. (R-GPTAFT)
//

import Foundation

/// 구매 화면에 표시할 상품 정보. 가격은 하드코딩하지 않고 Product.displayPrice를 그대로 쓴다.
struct StoreProductInfo: Sendable {
    let displayPrice: String
}

/// 구매 시도 결과.
enum PurchaseOutcome: Sendable {
    case success     // 구매(또는 즉시 검증) 완료
    case pending     // 승인 대기 (가족 승인 등) — 승인되면 업데이트로 자동 해제
    case cancelled   // 사용자가 취소했거나 검증 실패
}

/// StoreKit 2를 감싼 구매 서비스. 실제 구현은 StoreKitPurchaseService, 테스트는 Fake가 대신한다.
protocol PurchaseServiceProtocol: Sendable {
    /// 상품 정보를 불러온다(없으면 nil).
    func product() async throws -> StoreProductInfo?
    /// 평생 이용권을 구매한다.
    func purchase() async throws -> PurchaseOutcome
    /// 구매를 복원한다. 복원 후 권한이 있으면 true.
    func restore() async throws -> Bool
    /// 현재 권한(Transaction.currentEntitlements) 기준으로 평생 이용권을 보유 중인지.
    func currentlyUnlocked() async -> Bool
    /// 앱 실행 동안 Transaction.updates를 흘려보낸다(승인 대기 후 해제 등 반영용).
    func transactionUpdates() -> AsyncStream<Void>
}

/// 구매 여부를 읽고, 앱 시작 직후의 확인이 끝날 때까지 기다릴 수 있는 창구.
/// (구매자가 앱을 열자마자 구매 화면을 보지 않도록 게이트가 이 확인을 기다린다.)
@MainActor
protocol EntitlementProviding: AnyObject {
    /// 평생 이용권을 보유 중인지.
    var isUnlocked: Bool { get }
    /// 앱 시작 직후의 구매 여부 확인이 끝날 때까지 기다린다. (끝났으면 즉시 반환)
    func waitUntilReady() async
}
