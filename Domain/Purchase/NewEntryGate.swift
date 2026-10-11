//
//  NewEntryGate.swift
//  BlueHour
//
//  새 기록을 시작하는 입구 3곳(오늘 말하기·텍스트로 쓰기·하늘 달력 빈 과거 날짜)에서
//  공통으로 쓰는 게이트. 마이크·음성 인식 권한 요청보다 먼저 확인한다. (F-XUQOXA / PL-OBQXIP)
//

import Foundation

enum NewEntryGate {

    /// 새 기록을 시작해도 되는지.
    /// - 구매 여부 확인이 아직 끝나지 않았다면 끝날 때까지 기다린 뒤 판단한다
    ///   (구매자가 앱을 열자마자 구매 화면을 보지 않도록).
    /// - 평생 이용권이 있으면 항상 허용, 없으면 무료 한도에 도달하지 않았을 때만 허용.
    /// - 구매·카운트 의존성이 없으면(테스트 등) 제한하지 않는다.
    @MainActor
    static func canStartNewEntry(
        entitlement: EntitlementProviding?,
        counter: FreeSkyCounting?
    ) async -> Bool {
        guard let entitlement, let counter else { return true }
        await entitlement.waitUntilReady()
        if entitlement.isUnlocked { return true }
        return !counter.hasReachedLimit
    }
}
