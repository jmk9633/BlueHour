//
//  DebugSkyGenerator.swift
//  BlueHour
//
//  DEBUG 전용: 실제 FoundationModelSkyGenerator를 감싸 AI 상태(#4)·응답(#5)을 강제한다.
//  '실제 따름'이면 감싼 실제 구현에 그대로 위임한다.
//

#if DEBUG
import Foundation

struct DebugSkyGenerator: GeneratedSkyProducing {

    private let wrapped: GeneratedSkyProducing

    init(wrapping wrapped: GeneratedSkyProducing) {
        self.wrapped = wrapped
    }

    func isAvailable() async -> Bool {
        switch await currentAIState() {
        case .follow: return await wrapped.isAvailable()
        case .available: return true
        case .deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady: return false
        }
    }

    func isDeviceEligible() async -> Bool {
        switch await currentAIState() {
        case .follow: return await wrapped.isDeviceEligible()
        case .deviceNotEligible: return false
        // 하드웨어는 지원하되 소프트웨어 상태만 다른 경우는 '지원 기기'로 본다.
        case .available, .appleIntelligenceNotEnabled, .modelNotReady: return true
        }
    }

    func unavailableReason() async -> SkyUnavailableReason? {
        switch await currentAIState() {
        case .follow: return await wrapped.unavailableReason()
        case .available: return nil
        case .deviceNotEligible: return .deviceNotEligible
        case .appleIntelligenceNotEnabled: return .appleIntelligenceNotEnabled
        case .modelNotReady: return .modelNotReady
        }
    }

    func produce(text: String, reinforced: Bool) async throws -> SkyAnalysis {
        // 1) 사용 가능 상태 강제: 불가 계열이면 modelUnavailable.
        switch await currentAIState() {
        case .follow, .available:
            break
        case .deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady:
            throw SkyAnalysisError.modelUnavailable
        }

        // 2) 응답 강제.
        switch await currentAIResponse() {
        case .follow:
            return try await wrapped.produce(text: text, reinforced: reinforced)
        case .error:
            throw SkyAnalysisError.analysisFailed
        case .riskyThenClean:
            // 1차(reinforced=false)는 금지어 포함, 재생성(reinforced=true)은 정상.
            return reinforced ? Self.cleanSample() : Self.riskySample()
        case .riskyBoth:
            return Self.riskySample()
        }
    }

    // MARK: - DebugSettings 접근 (MainActor)

    private func currentAIState() async -> DebugSettings.AIState {
        await MainActor.run { DebugSettings.shared.aiState }
    }

    private func currentAIResponse() async -> DebugSettings.AIResponse {
        await MainActor.run { DebugSettings.shared.aiResponse }
    }

    // MARK: - 강제 응답 샘플

    /// 금지어(임상 표현)를 담은 응답. SkyExpressionPolicy가 잡아낸다.
    static func riskySample() -> SkyAnalysis {
        SkyAnalysis(
            weatherType: .lightRain,
            title: "번아웃이 온 하루",
            summary: "오늘 당신은 번아웃 상태로 보여요. 우울증이 의심되니 상담을 받아보세요.",
            emotionKeywords: ["번아웃", "소진"],
            mainTheme: "불안 수치가 높아 보여요.",
            recoverySignal: nil,
            tomorrowSentence: "고위험 신호가 있어요."
        )
    }

    /// 안전한 정상 응답.
    static func cleanSample() -> SkyAnalysis {
        SkyAnalysis(
            weatherType: .lightThroughClouds,
            title: "구름 사이로 든 빛",
            summary: "오늘은 마음이 조금 흐렸지만, 사이사이 작은 빛이 들었어요. 충분히 애쓴 하루였어요.",
            emotionKeywords: ["잔잔함", "회복"],
            mainTheme: "하루를 천천히 돌아봤어요.",
            recoverySignal: "스스로를 다독인 순간이 있었어요.",
            tomorrowSentence: "내일은 한 템포 쉬어가도 괜찮아요."
        )
    }
}
#endif
