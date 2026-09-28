//
//  BlueHourCalendar.swift
//  BlueHour
//
//  블루아워의 "하루" 경계를 한곳에서 관리한다.
//  하루는 자정이 아니라 새벽 4시에 바뀐다. 0시~3시 59분 사이는 아직 전날로 본다.
//  (잠들기 전에 쓰는 앱이라 자정 직후의 기록은 대부분 전날의 이야기이기 때문)
//
//  저장 규칙:
//  - DiaryEntry.date 는 항상 "논리적 하루의 자정"으로 정규화해 저장한다.
//    (예: 화요일 새벽 1시에 쓴 기록의 date 는 월요일 00:00)
//  - DiaryEntry.createdAt 에는 실제 작성 시각을 그대로 둔다.
//  이렇게 하면 저장소는 자정 기준으로 조회해도 정확히 논리적 하루와 맞아떨어진다.
//

import Foundation

enum BlueHourCalendar {

    /// 하루가 바뀌는 시각(시). 새벽 4시.
    static let boundaryHour = 4

    /// 주어진 시각이 속한 "논리적 하루"의 자정을 돌려준다.
    /// 새벽 4시 이전이면 전날로 본다.
    static func startOfLogicalDay(for date: Date, calendar: Calendar = .current) -> Date {
        // 4시간을 뺀 뒤 그날의 자정을 취하면, 0~3:59는 자연히 전날로 넘어간다.
        let shifted = calendar.date(byAdding: .hour, value: -boundaryHour, to: date) ?? date
        return calendar.startOfDay(for: shifted)
    }

    /// 지금 기준 "논리적 오늘"의 자정.
    static func startOfLogicalToday(now: Date = .now, calendar: Calendar = .current) -> Date {
        startOfLogicalDay(for: now, calendar: calendar)
    }

    /// 주어진 날짜가 논리적 오늘과 같은 하루에 속하는지.
    static func isLogicalToday(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        startOfLogicalDay(for: date, calendar: calendar) == startOfLogicalToday(now: now, calendar: calendar)
    }

    /// 주어진 날짜(달력상의 하루)가 아직 오지 않은 미래인지.
    /// 논리적 오늘이 마지막으로 기록 가능한 날이며, 그보다 뒤면 미래로 본다.
    /// (예: 새벽 1시에는 달력상 '오늘'도 논리적으로는 내일이므로 미래로 본다)
    static func isFuture(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: date) > startOfLogicalToday(now: now, calendar: calendar)
    }
}
