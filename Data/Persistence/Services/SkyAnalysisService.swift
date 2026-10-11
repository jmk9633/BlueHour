//
//  SkyAnalysisService.swift
//  BlueHour
//
//  '오늘의 하늘' 생성의 오케스트레이터.
//  생성(FoundationModelSkyGenerator) + 안전 표현 검사·대체(SkyExpressionPolicy)를 조합한다.
//
//  안전망 흐름 (PL-XNEFLR):
//   1) 1차 생성 → 위험 표현 없으면 그대로 반환.
//   2) 위험 표현이 있으면 강화 instructions로 '한 번만' 재생성.
//   3) 재생성 결과에도 남으면 걸린 필드만 대체(sanitize).
//   4) 재생성 자체가 실패하면 1차 결과에서 걸린 필드만 대체.
//  재생성은 최대 1회이며, weatherType은 언제나 유지된다.
//

import Foundation

actor SkyAnalysisService: SkyAnalysisServiceProtocol {

    private let generator: GeneratedSkyProducing
    private let policy: SkyExpressionPolicy

    init(
        generator: GeneratedSkyProducing = FoundationModelSkyGenerator(),
        policy: SkyExpressionPolicy = SkyExpressionPolicy()
    ) {
        self.generator = generator
        self.policy = policy
    }

    func isAvailable() async -> Bool {
        await generator.isAvailable()
    }

    func isDeviceEligible() async -> Bool {
        await generator.isDeviceEligible()
    }

    func analyze(text: String) async throws -> SkyAnalysis {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SkyAnalysisError.emptyTranscript
        }

        // 1차 생성 (modelUnavailable·analysisFailed는 그대로 전파)
        let first = try await generator.produce(text: trimmed, reinforced: false)
        if !policy.hasAnyRisky(first) {
            return first
        }

        // 위험 표현 감지 → 강화 instructions로 1회 재생성
        do {
            let second = try await generator.produce(text: trimmed, reinforced: true)
            // 재생성 결과에도 남으면 걸린 필드만 대체
            return policy.hasAnyRisky(second) ? policy.sanitize(second) : second
        } catch {
            // 재생성 자체가 실패하면 1차 결과에서 걸린 필드만 대체
            return policy.sanitize(first)
        }
    }
}
