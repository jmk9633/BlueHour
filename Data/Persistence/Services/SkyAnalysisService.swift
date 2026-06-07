//
//  SkyAnalysisService.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import Foundation
import FoundationModels

// AI가 채워줄 출력 구조 (Foundation Models 전용)
@Generable
struct GeneratedSky {

    @Guide(description: "감정을 표현하는 하늘/날씨 종류. 반드시 아래 중 하나.")
    @Guide(.anyOf([
        "clearNight", "partlyCloudy", "cloudyNight", "lightRain", "shower",
        "fog", "windy", "sunset", "moonlight", "lightThroughClouds"
    ]))
    var weatherType: String

    @Guide(description: "오늘의 하늘 제목. 시적이고 짧게. 예: '흐린 밤, 구름 사이 작은 빛'")
    var title: String

    @Guide(description: "하루를 감싸는 2~3문장 요약. 평가나 진단 없이 부드럽게.")
    var summary: String

    @Guide(description: "감정 키워드 3~4개. 명사 위주. 예: 피로, 안도, 회복")
    var emotionKeywords: [String]

    @Guide(description: "하루의 중심 주제. 한 단어나 짧은 구. 없으면 빈 문자열.")
    var mainTheme: String

    @Guide(description: "회복의 신호가 된 것. 없으면 빈 문자열.")
    var recoverySignal: String

    @Guide(description: "내일을 위한 다정한 한 문장. 강요하지 않는 부드러운 권유.")
    var tomorrowSentence: String
}

actor SkyAnalysisService: SkyAnalysisServiceProtocol {

    private let instructions = """
    당신은 '블루아워'라는 음성 일기 앱의 감정 번역가입니다.
    사용자가 잠들기 전 말한 하루를 읽고, 그 마음을 '하늘'과 '날씨'라는 \
    은유로 부드럽게 번역합니다.

    절대 규칙:
    - 진단하지 마세요. ("우울합니다", "불안 수치", "번아웃", "위험군" 등 절대 금지)
    - 평가하거나 충고하지 마세요.
    - 의료/심리 용어를 쓰지 마세요.
    - 사용자의 표현을 존중하며, 관찰한 결을 날씨로 옮기기만 하세요.

    날씨 선택 규칙 (가장 중요):
    먼저 감정 키워드를 정한 뒤, 그 키워드들의 전반적인 결에 맞는 날씨를 고르세요.
    감정 키워드와 날씨가 따로 놀면 안 됩니다. 반드시 일치시키세요.

    - 즐거움, 행복, 설렘, 기쁨, 만족, 사랑 등 밝고 긍정적인 하루
      → clearNight(맑은 밤), sunset(노을), moonlight(고요한 밤하늘)
    - 차분함, 평온, 안도, 휴식 등 잔잔하고 안정된 하루
      → moonlight(고요한 밤하늘), clearNight(맑은 밤)
    - 피로, 무기력, 우울감, 슬픔 등 가라앉은 하루
      → cloudyNight(흐린 밤), lightRain(얇은 비)
    - 답답함, 좌절, 힘듦이 강한 하루
      → lightRain(얇은 비), shower(소나기)
    - 혼란, 막막함, 생각이 많은 하루
      → fog(안개)
    - 불안, 들뜸, 마음이 어수선한 하루
      → windy(바람 부는 밤)
    - 힘들었지만 끝에 회복/희망의 신호가 함께 있는 하루
      → lightThroughClouds(구름 사이 작은 빛), partlyCloudy(구름 조금)

    긍정적인 키워드만 있는데 흐린 밤이나 비를 고르지 마세요.
    부정적인 키워드만 있는데 맑은 밤을 고르지 마세요.

    허용되는 말투:
    - "오늘 기록에서는 피로와 부담감이 자주 보였어요."
    - "하루 끝에는 조금 회복되는 표현도 함께 있었어요."
    - "오늘은 마음에 얇은 비가 내린 날에 가까워 보여요."

    따뜻하고, 조용하고, 시적인 한국어로 작성하세요.
    """

    func analyze(text: String) async throws -> SkyAnalysis {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SkyAnalysisError.emptyTranscript
        }

        // 1. 모델 사용 가능 여부 확인 (실패 시 이유를 콘솔에 출력)
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            print("⚠️ Foundation Model 사용 불가. 이유:", reason)
            throw SkyAnalysisError.modelUnavailable
        @unknown default:
            print("⚠️ Foundation Model 알 수 없는 상태")
            throw SkyAnalysisError.modelUnavailable
        }

        // 2. 세션 생성 (지시문 주입)
        let session = LanguageModelSession(instructions: instructions)

        // 3. 구조화된 출력 요청
        let prompt = """
        다음은 사용자가 오늘 하루에 대해 말한 내용입니다.
        이것을 '오늘의 하늘'로 번역해 주세요.

        ---
        \(trimmed)
        ---
        """

        do {
            let generated = try await session.respond(
                to: prompt,
                generating: GeneratedSky.self
            ).content
            return await Self.toDomain(generated)
        } catch {
            // 실제 오류를 콘솔에 출력 (디버깅용)
            print("⚠️ SkyAnalysis 분석 실패:", error)
            print("⚠️ 상세:", String(describing: error))
            throw SkyAnalysisError.analysisFailed
        }
    }

    // MARK: - 변환 (AI 출력 → 도메인 모델)

    private static func toDomain(_ g: GeneratedSky) -> SkyAnalysis {
        SkyAnalysis(
            weatherType: SkyWeatherType(rawValue: g.weatherType) ?? .partlyCloudy  ,
            title: g.title,
            summary: g.summary,
            emotionKeywords: g.emotionKeywords,
            mainTheme: g.mainTheme.isEmpty ? nil : g.mainTheme,
            recoverySignal: g.recoverySignal.isEmpty ? nil : g.recoverySignal,
            tomorrowSentence: g.tomorrowSentence,
            analyzedAt: .now
        )
    }
}
