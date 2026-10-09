//
//  SkyExpressionPolicyTests.swift
//  BlueHourTests
//
//  AI 분석 표현 정책(PL-XNEFLR)의 금지어 검사 + 필드별 대체 검증.
//

import XCTest
@testable import BlueHour

final class SkyExpressionPolicyTests: XCTestCase {

    private let policy = SkyExpressionPolicy()

    // MARK: - 금지어 탐지

    func test_detectsBannedTerms() {
        XCTAssertTrue(policy.isRisky("요즘 번아웃이 온 것 같아요"))
        XCTAssertTrue(policy.isRisky("불안 수치가 높게 나왔어요"))
        XCTAssertTrue(policy.isRisky("당신은 우울증입니다"))
        XCTAssertTrue(policy.isRisky("고위험 상태입니다"))
    }

    func test_cleanTextIsNotRisky() {
        XCTAssertFalse(policy.isRisky("오늘은 바다를 보며 마음이 잔잔해졌어요."))
        XCTAssertFalse(policy.isRisky("친구와 저녁을 먹고 많이 웃었어요."))
    }

    // MARK: - 과검출 방지 (요청 케이스)

    func test_doesNotOverDetect() {
        XCTAssertFalse(policy.isRisky("친구와 약속이 있어 즐거웠어요"), "'약속'이 '약'으로 걸리면 안 됨")
        XCTAssertFalse(policy.isRisky("약간 피곤했지만 괜찮았어요"), "'약간'이 걸리면 안 됨")
        XCTAssertFalse(policy.isRisky("조금 수치심을 느꼈지만 넘겼어요"), "'수치심'은 '수치'로 걸리면 안 됨")
        XCTAssertFalse(policy.isRisky("드디어 정상에 올랐다"), "'정상에 올랐다'는 걸리면 안 됨")
    }

    // MARK: - 필드별 대체

    private func makeAnalysis(
        weatherType: SkyWeatherType = .moonlight,
        title: String = "고요한 밤",
        summary: String = "잔잔하게 흘러간 하루였어요.",
        emotionKeywords: [String] = ["평온"],
        mainTheme: String? = nil,
        recoverySignal: String? = nil,
        tomorrowSentence: String = "편안한 밤 보내요."
    ) -> SkyAnalysis {
        SkyAnalysis(
            weatherType: weatherType,
            title: title,
            summary: summary,
            emotionKeywords: emotionKeywords,
            mainTheme: mainTheme,
            recoverySignal: recoverySignal,
            tomorrowSentence: tomorrowSentence
        )
    }

    func test_sanitize_replacesOnlyFlaggedTitle_keepsWeatherType() {
        let input = makeAnalysis(weatherType: .cloudyNight, title: "번아웃이 온 밤")
        let result = policy.sanitize(input)

        XCTAssertEqual(result.title, SkyWeatherType.cloudyNight.displayName, "걸린 title은 날씨 이름으로 대체")
        XCTAssertEqual(result.weatherType, .cloudyNight, "weatherType은 유지")
        XCTAssertEqual(result.summary, input.summary, "걸리지 않은 summary는 그대로")
    }

    func test_sanitize_replacesSummaryWithWeatherDraft() {
        let input = makeAnalysis(weatherType: .lightRain, summary: "당신은 우울증 상태입니다.")
        let result = policy.sanitize(input)
        XCTAssertEqual(result.summary, SkyExpressionPolicy.replacementSummaries[.lightRain])
    }

    func test_sanitize_replacesTomorrowWithCommonSentence() {
        let input = makeAnalysis(tomorrowSentence: "내일은 꼭 병원에 가야 합니다.")
        let result = policy.sanitize(input)
        XCTAssertTrue(
            SkyExpressionPolicy.commonTomorrowSentences.contains(result.tomorrowSentence),
            "걸린 내일 문장은 공통 대체 문장 중 하나여야 함"
        )
    }

    func test_sanitize_filtersOnlyRiskyKeywords() {
        let input = makeAnalysis(emotionKeywords: ["평온", "번아웃", "안도"])
        let result = policy.sanitize(input)
        XCTAssertEqual(result.emotionKeywords, ["평온", "안도"], "걸린 키워드만 제거")
    }

    func test_sanitize_hidesThemeAndRecoveryWhenRisky() {
        let input = makeAnalysis(
            mainTheme: "우울증 관리",
            recoverySignal: "치료를 시작한 것"
        )
        let result = policy.sanitize(input)
        XCTAssertNil(result.mainTheme)
        XCTAssertNil(result.recoverySignal)
    }

    func test_sanitize_keepsCleanFieldsUntouched() {
        let input = makeAnalysis(
            mainTheme: "오랜만의 산책",
            recoverySignal: "친구의 전화"
        )
        let result = policy.sanitize(input)
        XCTAssertEqual(result.mainTheme, "오랜만의 산책")
        XCTAssertEqual(result.recoverySignal, "친구의 전화")
    }
}
