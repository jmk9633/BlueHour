//
//  DebugToolsTests.swift
//  BlueHourTests
//
//  출시 전 테스트용 개발자 도구의 기본 동작 검증. DEBUG 빌드에서만 컴파일된다.
//

#if DEBUG
import XCTest
@testable import BlueHour

final class DebugToolsTests: XCTestCase {

    // 고정된 '현재 시각'으로 날짜 계산을 결정적으로 만든다. (2026-06-15 20:00)
    private let fixedNow: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 15; c.hour = 20
        return Calendar.current.date(from: c)!
    }()

    private let calendar = Calendar.current

    // MARK: - 샘플 생성 개수

    func test_weather10_makes10DistinctWeathersExcludingToday() {
        let entries = DebugSampleBuilder.weather10Entries(now: fixedNow)
        XCTAssertEqual(entries.count, 10)

        let weathers = Set(entries.compactMap { $0.analysis?.weatherType })
        XCTAssertEqual(weathers.count, 10, "날씨 10종이 모두 달라야 한다")

        let today = BlueHourCalendar.startOfLogicalDay(for: fixedNow)
        XCTAssertFalse(entries.contains { calendar.isDate($0.date, inSameDayAs: today) }, "오늘은 제외된다")
    }

    func test_undrawn_makes3WithoutAnalysis() {
        let entries = DebugSampleBuilder.undrawnEntries(now: fixedNow)
        XCTAssertEqual(entries.count, 3)
        XCTAssertTrue(entries.allSatisfy { $0.analysis == nil }, "아직 그려지지 않은 하늘은 analysis가 없다")
        XCTAssertTrue(entries.allSatisfy { $0.transcript != nil }, "원문은 있다")
    }

    func test_month_fillsAtLeastPreviousMonthAndExcludesToday() {
        let entries = DebugSampleBuilder.monthEntries(now: fixedNow)
        // 지난달(최소 28일) + 이번 달 1~14일 → 최소 28개 이상.
        XCTAssertGreaterThanOrEqual(entries.count, 28)
        let today = BlueHourCalendar.startOfLogicalDay(for: fixedNow)
        XCTAssertFalse(entries.contains { calendar.isDate($0.date, inSameDayAs: today) })
        // 날씨가 한 종류로 치우치지 않고 섞여 있다.
        XCTAssertGreaterThan(Set(entries.compactMap { $0.analysis?.weatherType }).count, 1)
    }

    // MARK: - 저장: 기존 날짜 건너뛰기 + 무료 카운트 미증가

    func test_save_skipsExistingDates_andDoesNotTouchCounter() async throws {
        let entries = DebugSampleBuilder.weather10Entries(now: fixedNow)
        // 첫 날짜에 이미 기록이 있는 상태로 시작.
        let repo = FakeDiaryRepository(seed: [DiaryEntry(date: entries[0].date)])
        let counter = await FreeSkyCounter(store: InMemoryFreeSkyCountStore(initial: 0))

        let result = try await DebugSampleBuilder.save(entries, repository: repo)

        XCTAssertEqual(result.inserted, 9)
        XCTAssertEqual(result.skipped, 1)
        let savedCount = await repo.saved.count
        XCTAssertEqual(savedCount, 10) // seed 1 + inserted 9
        let count = await counter.count
        XCTAssertEqual(count, 0, "샘플 생성은 무료 카운트를 늘리지 않는다")
    }

    // MARK: - 강제 '실제 따름'일 때 래핑 대상에 그대로 위임

    @MainActor
    func test_follow_skyGenerator_delegatesToWrapped() async throws {
        DebugSettings.shared.resetAllForcing()  // follow 상태
        let expected = FakeSkyAnalysisService.defaultSky
        let fake = FakeSkyGenerator(outputs: [.success(expected)], available: true)
        let debug = DebugSkyGenerator(wrapping: fake)

        let available = await debug.isAvailable()
        XCTAssertTrue(available)
        let produced = try await debug.produce(text: "오늘", reinforced: false)
        XCTAssertEqual(produced, expected)
    }

    @MainActor
    func test_follow_speechService_delegatesToWrapped() async throws {
        DebugSettings.shared.resetAllForcing()
        let fake = FakeSpeechRecognitionService(transcriptText: "안녕하세요")
        let debug = DebugSpeechService(wrapping: fake)

        let transcript = try await debug.transcribe(fileName: "x.m4a", languageCode: "ko-KR")
        XCTAssertEqual(transcript.originalText, "안녕하세요")
    }

    @MainActor
    func test_forcedError_skyGenerator_throws() async {
        DebugSettings.shared.resetAllForcing()
        DebugSettings.shared.aiResponse = .error
        let fake = FakeSkyGenerator(outputs: [.success(FakeSkyAnalysisService.defaultSky)])
        let debug = DebugSkyGenerator(wrapping: fake)
        do {
            _ = try await debug.produce(text: "오늘", reinforced: false)
            XCTFail("오류가 나야 한다")
        } catch {
            if case SkyAnalysisError.analysisFailed = error {
                // 기대한 오류
            } else {
                XCTFail("analysisFailed가 나야 한다: \(error)")
            }
        }
        DebugSettings.shared.resetAllForcing()
    }

    // MARK: - 실행 인자 파싱

    func test_launchArguments_parsesAll() {
        let args = [
            "-debugReset",
            "-debugFreeCount", "29",
            "-debugSeed", "weather10",
            "-debugSeed", "voice",
            "-debugAIState", "modelNotReady",
            "-debugSkipOnboarding",
            "-debugClock", "2026-01-02T03:04:05Z"
        ]
        let parsed = DebugLaunchArguments.parse(args)
        XCTAssertTrue(parsed.reset)
        XCTAssertEqual(parsed.freeCount, 29)
        XCTAssertEqual(parsed.seeds, [.weather10, .voice])
        XCTAssertEqual(parsed.aiState, .modelNotReady)
        XCTAssertTrue(parsed.skipOnboarding)
        XCTAssertNotNil(parsed.clock)
        XCTAssertFalse(parsed.isEmpty)
    }

    func test_launchArguments_emptyAndUnknownIgnored() {
        XCTAssertTrue(DebugLaunchArguments.parse([]).isEmpty)
        XCTAssertTrue(DebugLaunchArguments.parse(["-notAFlag", "value"]).isEmpty)
        // 값이 빠진 플래그는 무시된다.
        XCTAssertNil(DebugLaunchArguments.parse(["-debugFreeCount"]).freeCount)
        // 알 수 없는 seed·aiState 값은 무시된다.
        XCTAssertTrue(DebugLaunchArguments.parse(["-debugSeed", "nope"]).seeds.isEmpty)
        XCTAssertNil(DebugLaunchArguments.parse(["-debugAIState", "nope"]).aiState)
    }
}
#endif
