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

protocol SkyAnalysisServiceProtocol: Sendable {
    /// AI 분석을 지금 사용할 수 있는지.
    func isAvailable() async -> Bool

    /// 이 기기가 AI를 원천적으로 지원하는지. (하드웨어 미지원 기기만 false)
    /// 첫 실행 안내 ③ '기기 미지원' 안내 여부 판단에 쓴다.
    func isDeviceEligible() async -> Bool

    /// 일기 텍스트를 받아 "오늘의 하늘"로 분석.
    /// 절대 진단하지 않으며, 감정을 날씨 은유로 번역한다.
    func analyze(text: String) async throws -> SkyAnalysis
}
