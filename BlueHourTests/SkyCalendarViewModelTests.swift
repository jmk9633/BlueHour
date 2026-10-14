//
//  SkyCalendarViewModelTests.swift
//  BlueHourTests
//
//  하늘 달력(무드보드)의 집계·조회 검증. (F-QEQKFC)
//  - 날씨별 일수 요약(많은 순 정렬)
//  - 빈 달은 요약이 비어 있다
//  - '아직 그려지지 않은 하늘'(analysis 없음)도 그 날의 상세로 열 수 있게 entriesByDay에 남는다
//  - 미래 판정은 BlueHourCalendar를 따른다
//

import XCTest
@testable import BlueHour

@MainActor
final class SkyCalendarViewModelTests: XCTestCase {

    private let cal = Calendar.current

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.startOfDay(for: cal.date(from: DateComponents(year: y, month: m, day: d))!)
    }

    private func entry(_ date: Date, _ type: SkyWeatherType?) -> DiaryEntry {
        let analysis = type.map {
            SkyAnalysis(weatherType: $0, title: "제목", summary: "요약",
                        emotionKeywords: ["평온"], tomorrowSentence: "편안한 밤 보내요.")
        }
        return DiaryEntry(date: date, recording: nil,
                          transcript: DiaryTranscript(originalText: "글"), analysis: analysis)
    }

    func test_날씨별_일수는_많은순으로_집계된다() async {
        let entries = [
            entry(day(2026, 5, 1), .clearNight),
            entry(day(2026, 5, 2), .clearNight),
            entry(day(2026, 5, 3), .sunset)
        ]
        let vm = SkyCalendarViewModel(repository: FakeDiaryRepository(seed: entries))
        await vm.goTo(year: 2026, month: 5)

        XCTAssertEqual(vm.weatherCounts.map(\.type), [.clearNight, .sunset])
        XCTAssertEqual(vm.weatherCounts.map(\.count), [2, 1])
    }

    func test_빈_달은_요약이_비어있다() async {
        let vm = SkyCalendarViewModel(repository: FakeDiaryRepository(seed: []))
        await vm.goTo(year: 2026, month: 5)
        XCTAssertTrue(vm.weatherCounts.isEmpty)
    }

    func test_그려지지않은_하늘도_그날_상세로_열린다() async {
        let undrawn = entry(day(2026, 5, 10), nil)
        let vm = SkyCalendarViewModel(repository: FakeDiaryRepository(seed: [undrawn]))
        await vm.goTo(year: 2026, month: 5)

        // 하늘(analysis)은 없지만 기록은 그 날짜로 조회돼야 빈 날로 오인하지 않는다.
        XCTAssertNotNil(vm.entry(for: day(2026, 5, 10)), "미그림 기록도 entriesByDay에 있어야 합니다.")
        XCTAssertNil(vm.skyByDay[day(2026, 5, 10)], "미그림 기록은 skyByDay에 없어야 합니다.")
        XCTAssertTrue(vm.weatherCounts.isEmpty, "미그림 기록은 날씨 집계에 들어가지 않아야 합니다.")
    }

    func test_미래날짜_판정은_BlueHourCalendar를_따른다() {
        let vm = SkyCalendarViewModel(repository: FakeDiaryRepository(seed: []))
        let farFuture = cal.date(byAdding: .day, value: 2, to: BlueHourCalendar.startOfLogicalToday())!
        XCTAssertTrue(vm.isFuture(farFuture))
        XCTAssertFalse(vm.isFuture(BlueHourCalendar.startOfLogicalToday()))
    }
}
