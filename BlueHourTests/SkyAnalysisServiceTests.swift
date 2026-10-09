//
//  SkyAnalysisServiceTests.swift
//  BlueHourTests
//
//  안전망 오케스트레이션 검증: 재생성은 최대 1회, 그 뒤에는 필드별 대체.
//

import XCTest
@testable import BlueHour

final class SkyAnalysisServiceTests: XCTestCase {

    // 위험 표현이 들어간 결과 (title에 금지어)
    private func riskySky(title: String = "번아웃이 온 밤") -> SkyAnalysis {
        SkyAnalysis(
            weatherType: .cloudyNight,
            title: title,
            summary: "잔잔하게 흘러간 하루였어요.",
            emotionKeywords: ["평온"],
            tomorrowSentence: "편안한 밤 보내요."
        )
    }

    // 깨끗한 결과
    private func cleanSky(title: String = "고요한 밤") -> SkyAnalysis {
        SkyAnalysis(
            weatherType: .moonlight,
            title: title,
            summary: "달빛이 내려앉은 하루였어요.",
            emotionKeywords: ["평온"],
            tomorrowSentence: "편안한 밤 보내요."
        )
    }

    // MARK: - 1차가 깨끗하면 재생성하지 않는다

    func test_cleanFirst_noRegeneration() async throws {
        let generator = FakeSkyGenerator(outputs: [.success(cleanSky())])
        let service = SkyAnalysisService(generator: generator)

        let result = try await service.analyze(text: "오늘은 평온했어요.")

        XCTAssertEqual(result.title, "고요한 밤")
        let count = await generator.callCount
        XCTAssertEqual(count, 1, "1차가 깨끗하면 재생성하지 않아야 함")
    }

    // MARK: - 1차 위험 → 2차 깨끗이면 재생성 결과 사용 (정확히 2회)

    func test_riskyFirstThenClean_regeneratesOnce() async throws {
        let generator = FakeSkyGenerator(outputs: [
            .success(riskySky()),
            .success(cleanSky(title: "다시 그린 밤"))
        ])
        let service = SkyAnalysisService(generator: generator)

        let result = try await service.analyze(text: "오늘 하루 힘들었어요.")

        XCTAssertEqual(result.title, "다시 그린 밤", "깨끗한 재생성 결과를 사용")
        let count = await generator.callCount
        XCTAssertEqual(count, 2)
        let flags = await generator.reinforcedFlags
        XCTAssertEqual(flags, [false, true], "재생성은 강화 instructions(reinforced=true)로")
    }

    // MARK: - 1차·2차 모두 위험 → 2차를 대체, 재생성은 1회뿐

    func test_riskyBoth_sanitizesSecond_onlyOneRegeneration() async throws {
        let generator = FakeSkyGenerator(outputs: [
            .success(riskySky(title: "번아웃이 온 밤")),
            .success(riskySky(title: "여전히 번아웃"))
        ])
        let service = SkyAnalysisService(generator: generator)

        let result = try await service.analyze(text: "오늘 하루 힘들었어요.")

        // 2차(cloudyNight)의 걸린 title은 날씨 이름으로 대체, weatherType 유지
        XCTAssertEqual(result.title, SkyWeatherType.cloudyNight.displayName)
        XCTAssertEqual(result.weatherType, .cloudyNight)
        let count = await generator.callCount
        XCTAssertEqual(count, 2, "재생성은 최대 1회(총 2회 생성)")
    }

    // MARK: - 재생성이 실패하면 1차 결과를 대체

    func test_regenerationThrows_sanitizesFirst() async throws {
        let generator = FakeSkyGenerator(outputs: [
            .success(riskySky(title: "번아웃이 온 밤")),
            .failure(SkyAnalysisError.analysisFailed)
        ])
        let service = SkyAnalysisService(generator: generator)

        let result = try await service.analyze(text: "오늘 하루 힘들었어요.")

        XCTAssertEqual(result.title, SkyWeatherType.cloudyNight.displayName, "1차 결과를 대체해 반환")
        let count = await generator.callCount
        XCTAssertEqual(count, 2)
    }

    // MARK: - 빈 텍스트는 emptyTranscript

    func test_emptyText_throwsEmptyTranscript() async {
        let generator = FakeSkyGenerator(outputs: [.success(cleanSky())])
        let service = SkyAnalysisService(generator: generator)

        do {
            _ = try await service.analyze(text: "   ")
            XCTFail("빈 텍스트는 emptyTranscript를 던져야 함")
        } catch SkyAnalysisError.emptyTranscript {
            // 기대한 오류
        } catch {
            XCTFail("예상치 못한 오류: \(error)")
        }
    }

    // MARK: - 모델 미사용(1차 modelUnavailable)은 그대로 전파

    func test_modelUnavailable_propagates() async {
        let generator = FakeSkyGenerator(outputs: [.failure(SkyAnalysisError.modelUnavailable)])
        let service = SkyAnalysisService(generator: generator)

        do {
            _ = try await service.analyze(text: "오늘은 평온했어요.")
            XCTFail("modelUnavailable은 전파되어야 함")
        } catch SkyAnalysisError.modelUnavailable {
            // 기대한 오류
        } catch {
            XCTFail("예상치 못한 오류: \(error)")
        }
    }
}
