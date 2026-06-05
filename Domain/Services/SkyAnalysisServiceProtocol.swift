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
    /// 일기 텍스트를 받아 "오늘의 하늘"로 분석.
    /// 절대 진단하지 않으며, 감정을 날씨 은유로 번역한다.
    func analyze(text: String) async throws -> SkyAnalysis
}
