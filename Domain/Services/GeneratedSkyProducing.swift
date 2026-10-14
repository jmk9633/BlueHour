//
//  GeneratedSkyProducing.swift
//  BlueHour
//
//  모델이 '오늘의 하늘'을 생성하는 단계를 추상화한다.
//  실제 구현은 Apple Foundation Models를 쓰지만, 테스트에서는 가짜로 대체한다.
//

import Foundation

protocol GeneratedSkyProducing: Sendable {
    /// AI 모델을 지금 사용할 수 있는지.
    func isAvailable() async -> Bool

    /// 이 기기가 AI(온디바이스 모델)를 '원천적으로' 지원하는지.
    /// Apple Intelligence가 꺼져 있거나 모델이 준비 중인 지원 기기는 true,
    /// 하드웨어가 미지원(deviceNotEligible)인 기기만 false를 돌려준다.
    /// (첫 실행 안내 ③ '기기 미지원'을 가려내기 위한 용도)
    func isDeviceEligible() async -> Bool

    /// 지금 모델을 쓸 수 없다면 그 이유. 쓸 수 있으면 nil. (S-MEOLWE 상태별 안내)
    func unavailableReason() async -> SkyUnavailableReason?

    /// 일기 텍스트로부터 SkyAnalysis를 생성한다.
    /// - Parameter reinforced: 비진단 표현을 더 강하게 지시하는 instructions를 쓸지 여부(재생성 시 true).
    func produce(text: String, reinforced: Bool) async throws -> SkyAnalysis
}
