//
//  SkyCalendarViewModel.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class SkyCalendarViewModel {

    // MARK: - 화면이 바라보는 상태

    /// 현재 보고 있는 달 (그 달의 1일)
    private(set) var currentMonth: Date = Calendar.current.startOfDay(for: .now)

    /// 날짜 → 그날의 하늘 (분석이 있는 날만)
    private(set) var skyByDay: [Date: SkyAnalysis] = [:]

    /// 날짜 → 그날의 일기 전체 (분석이 있는 날만)
    private(set) var entriesByDay: [Date: DiaryEntry] = [:]

    /// 날씨 종류별 일수. 예: [.clearNight: 6, .cloudyNight: 9]
    private(set) var weatherCounts: [(type: SkyWeatherType, count: Int)] = []

    private(set) var isLoading = false

    // MARK: - 의존성

    private let repository: DiaryRepositoryProtocol

    init(repository: DiaryRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - 표시용 문자열

    /// "2026년 5월의 하늘"
    var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return "\(formatter.string(from: currentMonth))의 하늘"
    }

    /// 현재 보고 있는 달의 연도/월 (휠 피커 기본값에 사용)
    var year: Int { Calendar.current.component(.year, from: currentMonth) }
    var month: Int { Calendar.current.component(.month, from: currentMonth) }

    // MARK: - 데이터 로드

    func load() async {
        isLoading = true
        defer { isLoading = false }

        guard let interval = monthInterval(for: currentMonth) else { return }

        do {
            let entries = try await repository.fetchEntries(in: interval)
            buildState(from: entries)
        } catch {
            skyByDay = [:]
            entriesByDay = [:]
            weatherCounts = []
        }
    }

    // MARK: - 달 이동

    func goToPreviousMonth() async {
        if let prev = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = Calendar.current.startOfDay(for: prev)
            await load()
        }
    }

    func goToNextMonth() async {
        if let next = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = Calendar.current.startOfDay(for: next)
            await load()
        }
    }

    /// 휠 피커에서 고른 연도/월로 이동
    func goTo(year: Int, month: Int) async {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        if let date = Calendar.current.date(from: components) {
            currentMonth = Calendar.current.startOfDay(for: date)
            await load()
        }
    }

    // MARK: - 날짜로 일기 찾기

    /// 달력에서 특정 날짜를 탭했을 때 그날의 일기를 반환 (없으면 nil)
    func entry(for day: Date) -> DiaryEntry? {
        entriesByDay[Calendar.current.startOfDay(for: day)]
    }

    // MARK: - 날짜 판단 (새벽 4시 경계 기준)

    /// 아직 오지 않은 미래 날짜인지. 논리적 오늘이 마지막으로 기록 가능한 날이다.
    /// (새벽 1시에는 달력상 '오늘'도 논리적으로는 내일이라 미래로 본다)
    func isFuture(_ day: Date) -> Bool {
        BlueHourCalendar.isFuture(day)
    }

    /// 논리적 오늘에 해당하는 날짜인지 (달력에서 오늘 표시에 사용)
    func isToday(_ day: Date) -> Bool {
        BlueHourCalendar.isLogicalToday(day)
    }

    // MARK: - Private

    private func buildState(from entries: [DiaryEntry]) {
        var byDay: [Date: SkyAnalysis] = [:]
        var entryByDay: [Date: DiaryEntry] = [:]
        var counts: [SkyWeatherType: Int] = [:]

        for entry in entries {
            guard let analysis = entry.analysis else { continue }
            let day = Calendar.current.startOfDay(for: entry.date)
            byDay[day] = analysis
            entryByDay[day] = entry
            counts[analysis.weatherType, default: 0] += 1
        }

        skyByDay = byDay
        entriesByDay = entryByDay
        // 많이 나온 날씨 순으로 정렬
        weatherCounts = counts
            .map { (type: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private func monthInterval(for date: Date) -> DateInterval? {
        let calendar = Calendar.current
        guard let monthStart = calendar.dateInterval(of: .month, for: date)?.start,
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)
        else { return nil }
        return DateInterval(start: monthStart, end: monthEnd)
    }

    /// 화면에서 달력 그리드를 그릴 때 쓸 날짜 배열 (그 달의 모든 날)
    func daysInCurrentMonth() -> [Date] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let monthStart = calendar.dateInterval(of: .month, for: currentMonth)?.start
        else { return [] }

        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthStart)
        }
    }
}
