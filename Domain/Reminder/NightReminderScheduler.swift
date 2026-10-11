//
//  NightReminderScheduler.swift
//  BlueHour
//
//  밤 리마인더 예약의 '두뇌'. 매일 반복 알림이 아니라 앞으로 7일 치를 하루에 하나씩 개별 예약한다.
//  reschedule() 하나로 기존 예약을 모두 지우고 기록이 없는 논리 날짜에만 새로 예약한다. (PL-OZYYZI)
//
//  날짜 규칙(BlueHourCalendar, 새벽 4시 경계 재사용):
//   - 알림 시각이 4시 이후면 그 논리 날짜 당일에 발송한다.
//   - 알림 시각이 0:00~3:59면 다음 캘린더일 새벽에 발송한다(= 전날 논리 날짜의 알림).
//   - 해당 논리 날짜에 기록이 있으면 그날 알림은 예약하지 않는다.
//   - 이미 지난 시각은 예약하지 않는다.
//

import Foundation

@MainActor
final class NightReminderScheduler {

    /// 밤 리마인더 알림 식별자의 공통 접두사. 날짜별 취소를 위해 뒤에 논리 날짜(yyyy-MM-dd)를 붙인다.
    static let identifierPrefix = "night-reminder-"

    /// 한 번에 예약하는 최대 알림 수.
    static let maxScheduled = 7

    /// 알림 문구 3종(PL-OZYYZI display 그대로). 논리 날짜에 따라 번갈아 쓴다.
    static let messages = [
        "오늘의 하늘을 남길 시간이에요.",
        "길지 않아도 괜찮아요. 60초면 충분해요.",
        "잠들기 전, 오늘은 어떤 하늘이었나요?"
    ]

    private let center: NotificationScheduling
    private let repository: DiaryRepositoryProtocol
    private let entitlement: EntitlementProviding?
    private let counter: FreeSkyCounting?
    private let defaults: UserDefaults
    private let now: () -> Date
    private let calendar: Calendar

    init(
        center: NotificationScheduling,
        repository: DiaryRepositoryProtocol,
        entitlement: EntitlementProviding?,
        counter: FreeSkyCounting?,
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = { Date() },
        calendar: Calendar = .current
    ) {
        self.center = center
        self.repository = repository
        self.entitlement = entitlement
        self.counter = counter
        self.defaults = defaults
        self.now = now
        self.calendar = calendar
    }

    // MARK: - 재예약 (하나의 함수)

    /// 기존 리마인더 예약을 모두 지우고, 조건을 만족하면 기록이 없는 논리 날짜에 최대 7개를 새로 예약한다.
    func reschedule() async {
        // 1. 우리가 예약한 알림을 모두 취소한다(날짜별 식별자 기준).
        let existing = await center.pendingReminderIdentifiers()
        if !existing.isEmpty {
            await center.removeReminders(identifiers: existing)
        }

        // 2. 게이트: 토글이 꺼져 있으면 예약하지 않는다.
        guard defaults.bool(forKey: AppSettings.Keys.reminderEnabled) else { return }

        // 3. 게이트: 알림 권한이 허용되어 있지 않으면 예약하지 않는다.
        guard await center.authorizationStatus() == .authorized else { return }

        // 4. 게이트: 무료 30개를 채운 미구매자에게는 예약하지 않는다.
        //    구매 여부 확인이 끝나기 전이면 기다린 뒤 판단한다(구매자의 알림이 잘못 지워지지 않게).
        if let entitlement {
            await entitlement.waitUntilReady()
            if !entitlement.isUnlocked, let counter, counter.hasReachedLimit {
                return
            }
        }

        // 5. 논리 오늘부터 하루씩, 기록이 없는 날에만 최대 7개를 예약한다.
        let hour = defaults.integer(forKey: AppSettings.Keys.reminderHour)
        let minute = defaults.integer(forKey: AppSettings.Keys.reminderMinute)
        let currentTime = now()
        let logicalToday = BlueHourCalendar.startOfLogicalDay(for: currentTime, calendar: calendar)

        var scheduled = 0
        var offset = 0
        // 미래 날짜는 항상 기록이 없으므로 보통 offset 0~6에서 7개가 채워진다.
        // 안전을 위해 상한을 넉넉히 둔다.
        let offsetLimit = Self.maxScheduled + 7

        while scheduled < Self.maxScheduled && offset < offsetLimit {
            let logicalDay = calendar.date(byAdding: .day, value: offset, to: logicalToday) ?? logicalToday
            offset += 1

            // 그 논리 날짜에 기록이 있으면 건너뛴다(오늘 기록이 있으면 오늘 알림 없음).
            // 과거 날짜 기록은 여기(미래 방향 순회)에 들어오지 않으므로 자연히 영향이 없다.
            if let found = try? await repository.fetchEntry(on: logicalDay), found != nil {
                continue
            }

            guard let fireDate = fireDate(forLogicalDay: logicalDay, hour: hour, minute: minute) else {
                continue
            }
            // 이미 지난 시각은 예약하지 않는다.
            if fireDate <= currentTime { continue }

            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            await center.scheduleReminder(
                identifier: identifier(for: logicalDay),
                body: message(for: logicalDay),
                at: components
            )
            scheduled += 1
        }
    }

    // MARK: - 보조 계산

    /// 논리 날짜의 발송 시각(Date). 시각이 4시 이후면 그 날, 0~3:59면 다음 캘린더일에 발송한다.
    private func fireDate(forLogicalDay logicalDay: Date, hour: Int, minute: Int) -> Date? {
        let baseDate: Date
        if hour >= BlueHourCalendar.boundaryHour {
            baseDate = logicalDay
        } else {
            // 0:00~3:59 알림은 논리 날짜의 '다음 캘린더 새벽'에 울린다.
            baseDate = calendar.date(byAdding: .day, value: 1, to: logicalDay) ?? logicalDay
        }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate)
    }

    /// 논리 날짜 기준 알림 식별자. 날짜별로 취소할 수 있게 yyyy-MM-dd를 붙인다.
    private func identifier(for logicalDay: Date) -> String {
        Self.identifierPrefix + Self.dateKey(for: logicalDay, calendar: calendar)
    }

    /// 논리 날짜에 따라 번갈아 쓰는 알림 문구.
    private func message(for logicalDay: Date) -> String {
        let dayNumber = calendar.ordinality(of: .day, in: .era, for: logicalDay) ?? 0
        let index = ((dayNumber % Self.messages.count) + Self.messages.count) % Self.messages.count
        return Self.messages[index]
    }

    /// 식별자에 쓰는 날짜 문자열(yyyy-MM-dd). 테스트에서도 같은 포맷을 쓰도록 노출한다.
    static func dateKey(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }
}
