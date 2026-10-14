//
//  SkyAnalysisServiceProtocol.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import Foundation

enum SkyAnalysisError: Error, Sendable {
    case modelUnavailable
    case emptyTranscript
    case analysisFailed
    case decodingFailed
}

/// AI를 지금 쓸 수 없는 이유. '아직 그려지지 않은 하늘' 결과 화면의 안내 문구를 가른다. (PL-FUVSGO / S-MEOLWE)
enum SkyUnavailableReason: Sendable, Equatable {
    case deviceNotEligible           // 하드웨어 미지원(iPhone 15 Pro 이전)
    case appleIntelligenceNotEnabled // 지원 기기지만 설정에서 꺼 둠
    case modelNotReady               // 모델 다운로드/준비 중
}

protocol SkyAnalysisServiceProtocol: Sendable {
    /// AI 분석을 지금 사용할 수 있는지.
    func isAvailable() async -> Bool

    /// 이 기기가 AI를 원천적으로 지원하는지. (하드웨어 미지원 기기만 false)
    /// 첫 실행 안내 ③ '기기 미지원' 안내 여부 판단에 쓴다.
    func isDeviceEligible() async -> Bool

    /// 지금 AI를 쓸 수 없다면 그 이유. 쓸 수 있으면 nil.
    /// '아직 그려지지 않은 하늘' 화면에서 상태별 안내를 고르는 데 쓴다. (S-MEOLWE)
    func unavailableReason() async -> SkyUnavailableReason?

    /// 일기 텍스트를 받아 "오늘의 하늘"로 분석.
    /// 절대 진단하지 않으며, 감정을 날씨 은유로 번역한다.
    func analyze(text: String) async throws -> SkyAnalysis
}
