//
//  PurchaseController.swift
//  BlueHour
//
//  구매 상태(평생 이용권 보유 여부·가격·구매/복원 결과)를 담는 화면용 컨트롤러.
//  앱 실행 동안 Transaction.updates를 들어 승인 대기 후 자동 해제를 반영한다. (F-MVCMCF / F-WURMKT)
//

import Foundation
import Observation

@MainActor
@Observable
final class PurchaseController: EntitlementProviding {

    /// 평생 이용권을 보유 중인지.
    private(set) var isUnlocked = false {
        didSet {
            // 잠금 해제로 '막' 바뀐 순간에만 알린다(구매 완료 시 밤 리마인더 재예약 트리거).
            if isUnlocked && !oldValue { onUnlock?() }
        }
    }

    /// 평생 이용권 보유로 전환된 순간 호출되는 콜백. (DIContainer가 밤 리마인더 재예약에 연결)
    var onUnlock: (() -> Void)?
    /// 앱 시작 직후의 구매 여부 확인이 끝났는지.
    private(set) var isReady = false
    /// 구매 화면에 표시할 가격(Product.displayPrice). 로드 전/실패 시 nil.
    private(set) var displayPrice: String?
    /// 상품 정보를 불러오지 못했는지(네트워크 문제 등).
    private(set) var loadFailed = false
    /// 결제가 승인 대기 상태인지(가족 승인 등).
    private(set) var purchasePending = false

    private let service: PurchaseServiceProtocol
    private var startTask: Task<Void, Never>?
    private var updatesTask: Task<Void, Never>?

    init(service: PurchaseServiceProtocol) {
        self.service = service
    }

    // MARK: - 앱 실행 시작 시 1회 기동

    /// 현재 권한을 확인하고, 이후 트랜잭션 업데이트를 듣기 시작한다.
    func start() {
        guard startTask == nil else { return }
        startTask = Task { [weak self] in
            guard let self else { return }
            let unlocked = await self.service.currentlyUnlocked()
            self.isUnlocked = unlocked
            self.isReady = true
        }
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await _ in self.service.transactionUpdates() {
                self.isUnlocked = await self.service.currentlyUnlocked()
            }
        }
    }

    /// 앱 시작 직후의 구매 여부 확인이 끝날 때까지 기다린다.
    func waitUntilReady() async {
        await startTask?.value
    }

    // MARK: - 구매 화면 동작

    /// 구매 화면 진입 시 상품 가격을 불러온다.
    func loadProduct() async {
        loadFailed = false
        do {
            if let info = try await service.product() {
                displayPrice = info.displayPrice
            } else {
                loadFailed = true
            }
        } catch {
            loadFailed = true
        }
    }

    /// 평생 이용권 구매. 성공하면 true(제한 해제). 승인 대기/취소/실패는 false.
    func purchase() async -> Bool {
        purchasePending = false
        do {
            switch try await service.purchase() {
            case .success:
                isUnlocked = true
                return true
            case .pending:
                purchasePending = true
                return false
            case .cancelled:
                return false
            }
        } catch {
            return false
        }
    }

    /// 구매 복원. 결과 안내 문구를 돌려준다. (F-WURMKT display 그대로)
    func restore() async -> String {
        do {
            if try await service.restore() {
                isUnlocked = true
                return "평생 이용권을 다시 불러왔어요."
            } else {
                return "불러올 구매 내역이 없어요."
            }
        } catch {
            return "잠시 후 다시 시도해 주세요."
        }
    }
}
