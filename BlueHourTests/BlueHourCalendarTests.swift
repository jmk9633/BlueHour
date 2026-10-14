//
//  BlueHourCalendarTests.swift
//  BlueHourTests
//
//  하루 경계(새벽 4시)와 과거/미래 판정 검증. (PL-SSBBVZ)
//

import XCTest
@testable import BlueHour

final class BlueHourCalendarTests: XCTestCase {

    /// 날짜 조립·비교를 결정적으로 하기 위해 고정 캘린더(서울)를 쓴다.
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ hh: Int = 0, _ mm: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hh, minute: mm))!
    }

    // MARK: - 논리적 하루의 자정으로 정규화

    func test_새벽4시이전은_전날로_본다() {
        // 5월 12일 새벽 2시에 쓴 기록 → 논리 날짜는 5월 11일 자정
        let result = BlueHourCalendar.startOfLogicalDay(for: date(2026, 5, 12, 2, 30), calendar: calendar)
        XCTAssertEqual(result, date(2026, 5, 11, 0, 0))
    }

    func test_정확히_새벽4시는_당일로_본다() {
        let result = BlueHourCalendar.startOfLogicalDay(for: date(2026, 5, 12, 4, 0), calendar: calendar)
        XCTAssertEqual(result, date(2026, 5, 12, 0, 0))
    }

    func test_오전10시는_당일로_본다() {
        let result = BlueHourCalendar.startOfLogicalDay(for: date(2026, 5, 12, 10, 0), calendar: calendar)
        XCTAssertEqual(result, date(2026, 5, 12, 0, 0))
    }

    // MARK: - 미래 판정 (새벽 4시 경계)

    func test_미래날짜_판정() {
        let now = date(2026, 5, 12, 10, 0)   // 논리 오늘 = 5/12
        XCTAssertTrue(BlueHourCalendar.isFuture(date(2026, 5, 13), now: now, calendar: calendar))
        XCTAssertFalse(BlueHourCalendar.isFuture(date(2026, 5, 12), now: now, calendar: calendar))
        XCTAssertFalse(BlueHourCalendar.isFuture(date(2026, 5, 11), now: now, calendar: calendar))
    }

    func test_새벽에는_달력상_오늘도_미래로_본다() {
        // 5/12 새벽 1시 → 논리 오늘은 5/11이므로, 달력상 '오늘'(5/12)은 아직 미래다.
        let now = date(2026, 5, 12, 1, 0)
        XCTAssertTrue(BlueHourCalendar.isFuture(date(2026, 5, 12), now: now, calendar: calendar))
        XCTAssertTrue(BlueHourCalendar.isLogicalToday(date(2026, 5, 11), now: now, calendar: calendar))
        XCTAssertFalse(BlueHourCalendar.isLogicalToday(date(2026, 5, 12), now: now, calendar: calendar))
    }
}
