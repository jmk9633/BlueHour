//
//  NightReminderTests.swift
//  BlueHourTests
//
//  7단계(밤 리마인더): 7일 개별 예약, 오늘 기록 유무, 0~4시 알림 시각, 지난 시각 제외,
//  7개 상한, 무료 30개 미구매자 예약 없음→구매 후 예약, 권한 꺼짐, 오늘 기록 삭제 후 재예약,
//  과거 날짜 무영향, 재예약이 기존 예약 먼저 취소, 첫 기록 제안 1회.
//

import XCTest
@testable import BlueHour

@MainActor
final class NightReminderTests: XCTestCase {

    // MARK: - 고정 시각/달력

    /// 그레고리력(현재 타임존). now는 2026-06-15 20:00(= 논리 오늘 06-15, 22:30 알림은 미래).
    private let calendar = Calendar(identifier: .gregorian)

    private func fixedNow(hour: Int = 20, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 15
        comps.hour = hour; comps.minute = minute
        return calendar.date(from: comps)!
    }

    /// 특정 (년,월,일) 자정 Date — 기록 시드/식별자 비교용.
    private func day(_ year: Int, _ month: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: d))!
    }

    private func dateKey(_ year: Int, _ month: Int, _ d: Int) -> String {
        NightReminderScheduler.dateKey(for: day(year, month, d), calendar: calendar)
    }

    // MARK: - 헬퍼

    private func makeDefaults(
        enabled: Bool = true,
        hour: Int = 22,
        minute: Int = 30,
        promptShown: Bool = false
    ) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "reminder.\(UUID().uuidString)")!
        AppSettings.registerDefaults(defaults)
        defaults.set(enabled, forKey: AppSettings.Keys.reminderEnabled)
        defaults.set(hour, forKey: AppSettings.Keys.reminderHour)
        defaults.set(minute, forKey: AppSettings.Keys.reminderMinute)
        defaults.set(promptShown, forKey: AppSettings.Keys.hasShownReminderPrompt)
        return defaults
    }

    private func makeScheduler(
        center: FakeNotificationScheduler,
        repository: FakeDiaryRepository = FakeDiaryRepository(),
        entitlement: FakeEntitlement? = nil,
        counter: FreeSkyCounter? = nil,
        defaults: UserDefaults,
        now: Date? = nil
    ) -> NightReminderScheduler {
        NightReminderScheduler(
            center: center,
            repository: repository,
            entitlement: entitlement,
            counter: counter,
            defaults: defaults,
            now: { now ?? self.fixedNow() },
            calendar: calendar
        )
    }

    // MARK: - 7일 예약 / 오늘 기록 유무

    func testSchedulesSevenStartingTodayWhenNoRecord() async {
        let center = FakeNotificationScheduler()
        let scheduler = makeScheduler(center: center, defaults: makeDefaults())

        await scheduler.reschedule()

        XCTAssertEqual(center.scheduled.count, 7)
        XCTAssertTrue(center.hasScheduled(dateKey: dateKey(2026, 6, 15)))
        XCTAssertEqual(center.scheduledIdentifiers.first, NightReminderScheduler.identifierPrefix + dateKey(2026, 6, 15))
    }

    func testSkipsTodayWhenTodayHasRecord() async {
        let center = FakeNotificationScheduler()
        let repo = FakeDiaryRepository(seed: [DiaryEntry(date: day(2026, 6, 15))])
        let scheduler = makeScheduler(center: center, repository: repo, defaults: makeDefaults())

        await scheduler.reschedule()

        XCTAssertEqual(center.scheduled.count, 7)
        XCTAssertFalse(center.hasScheduled(dateKey: dateKey(2026, 6, 15)))
        XCTAssertTrue(center.hasScheduled(dateKey: dateKey(2026, 6, 16)))
    }

    // MARK: - 0~4시 알림 시각 (전날 논리 날짜, 다음 캘린더 새벽 발송)

    func testEarlyMorningTimeFiresNextCalendarDay() async {
        let center = FakeNotificationScheduler()
        let scheduler = makeScheduler(center: center, defaults: makeDefaults(hour: 1, minute: 0))

        await scheduler.reschedule()

        XCTAssertEqual(center.scheduled.count, 7)
        // 논리 오늘(06-15)의 알림은 06-16 새벽 1시에 울린다.
        let first = center.scheduled.first!
        XCTAssertEqual(first.identifier, NightReminderScheduler.identifierPrefix + dateKey(2026, 6, 15))
        XCTAssertEqual(first.components.hour, 1)
        XCTAssertEqual(first.components.day, 16)
    }

    // MARK: - 지난 시각 제외

    func testSkipsTodayWhenTimeAlreadyPassed() async {
        let center = FakeNotificationScheduler()
        // now = 23:00, 알림 22:30 → 오늘 발송 시각은 이미 지났다.
        let scheduler = makeScheduler(center: center, defaults: makeDefaults(), now: fixedNow(hour: 23, minute: 0))

        await scheduler.reschedule()

        XCTAssertEqual(center.scheduled.count, 7)
        XCTAssertFalse(center.hasScheduled(dateKey: dateKey(2026, 6, 15)))
        XCTAssertEqual(center.scheduledIdentifiers.first, NightReminderScheduler.identifierPrefix + dateKey(2026, 6, 16))
    }

    // MARK: - 7개 상한

    func testNeverSchedulesMoreThanSeven() async {
        let center = FakeNotificationScheduler()
        let scheduler = makeScheduler(center: center, defaults: makeDefaults())

        await scheduler.reschedule()

        XCTAssertLessThanOrEqual(center.scheduled.count, NightReminderScheduler.maxScheduled)
        XCTAssertEqual(center.scheduled.count, 7)
    }

    // MARK: - 무료 30개 미구매자 예약 없음 → 구매 후 예약

    func testNoScheduleForFreeLimitReachedThenSchedulesAfterPurchase() async {
        let center = FakeNotificationScheduler()
        let entitlement = FakeEntitlement(isUnlocked: false, ready: true)
        let counter = FreeSkyCounter(store: InMemoryFreeSkyCountStore(initial: 30), limit: 30)
        let scheduler = makeScheduler(
            center: center,
            entitlement: entitlement,
            counter: counter,
            defaults: makeDefaults()
        )

        await scheduler.reschedule()
        XCTAssertTrue(center.scheduled.isEmpty)

        // 구매 완료 → 다시 예약된다.
        entitlement.isUnlocked = true
        await scheduler.reschedule()
        XCTAssertEqual(center.scheduled.count, 7)
    }

    // MARK: - 권한 꺼짐

    func testNoScheduleWhenPermissionDenied() async {
        let center = FakeNotificationScheduler(status: .authorized)
        let scheduler = makeScheduler(center: center, defaults: makeDefaults())

        // 먼저 정상 예약
        await scheduler.reschedule()
        XCTAssertEqual(center.scheduled.count, 7)

        // 권한이 꺼지면 재예약 시 기존 예약을 지우고 새로 예약하지 않는다.
        center.status = .denied
        await scheduler.reschedule()
        XCTAssertTrue(center.scheduled.isEmpty)
        XCTAssertFalse(center.removedCalls.isEmpty)
    }

    // MARK: - 토글 꺼짐

    func testNoScheduleWhenDisabled() async {
        let center = FakeNotificationScheduler()
        let scheduler = makeScheduler(center: center, defaults: makeDefaults(enabled: false))

        await scheduler.reschedule()

        XCTAssertTrue(center.scheduled.isEmpty)
    }

    // MARK: - 오늘 기록 삭제 후 재예약

    func testTodayReschedulesAfterTodayRecordDeleted() async {
        let center = FakeNotificationScheduler()
        let todayEntry = DiaryEntry(date: day(2026, 6, 15))
        let repo = FakeDiaryRepository(seed: [todayEntry])
        let scheduler = makeScheduler(center: center, repository: repo, defaults: makeDefaults())

        await scheduler.reschedule()
        XCTAssertFalse(center.hasScheduled(dateKey: dateKey(2026, 6, 15)))

        // 오늘 기록 삭제 후 재예약 → 오늘 알림이 다시 들어간다.
        try? await repo.delete(id: todayEntry.id)
        await scheduler.reschedule()
        XCTAssertTrue(center.hasScheduled(dateKey: dateKey(2026, 6, 15)))
        XCTAssertEqual(center.scheduled.count, 7)
    }

    // MARK: - 과거 날짜 기록은 무영향

    func testPastRecordDoesNotAffectScheduling() async {
        let center = FakeNotificationScheduler()
        // 5일 전(06-10) 기록이 있어도 오늘부터 7개가 그대로 예약된다.
        let repo = FakeDiaryRepository(seed: [DiaryEntry(date: day(2026, 6, 10))])
        let scheduler = makeScheduler(center: center, repository: repo, defaults: makeDefaults())

        await scheduler.reschedule()

        XCTAssertEqual(center.scheduled.count, 7)
        XCTAssertTrue(center.hasScheduled(dateKey: dateKey(2026, 6, 15)))
        XCTAssertFalse(center.hasScheduled(dateKey: dateKey(2026, 6, 10)))
    }

    // MARK: - 재예약이 기존 예약을 먼저 취소

    func testRescheduleCancelsPreviousFirst() async {
        let center = FakeNotificationScheduler()
        let scheduler = makeScheduler(center: center, defaults: makeDefaults())

        await scheduler.reschedule()
        let firstBatch = Set(center.scheduledIdentifiers)
        XCTAssertEqual(firstBatch.count, 7)

        await scheduler.reschedule()
        // 두 번째 reschedule이 첫 배치를 모두 취소하고 다시 7개를 예약한다.
        XCTAssertEqual(center.scheduled.count, 7)
        XCTAssertTrue(center.removedCalls.contains { Set($0) == firstBatch })
    }

    // MARK: - 문구 3종 번갈아

    func testMessagesRotateAcrossConsecutiveDays() async {
        let center = FakeNotificationScheduler()
        let scheduler = makeScheduler(center: center, defaults: makeDefaults())

        await scheduler.reschedule()

        let firstThree = center.scheduled.prefix(3).map(\.body)
        XCTAssertEqual(Set(firstThree).count, 3, "연속한 3일은 서로 다른 문구를 쓴다")
        XCTAssertTrue(firstThree.allSatisfy { NightReminderScheduler.messages.contains($0) })
    }

    // MARK: - 첫 기록 제안 1회 (컨트롤러)

    func testPromptShownOnceAndGuardedOnDisplay() async {
        let defaults = makeDefaults(enabled: false, promptShown: false)
        let center = FakeNotificationScheduler()
        let scheduler = makeScheduler(center: center, defaults: defaults)
        let controller = NightReminderController(scheduler: scheduler, center: center, defaults: defaults)

        // 아직 제안한 적 없고 리마인더도 꺼져 있으면 제안한다.
        XCTAssertTrue(controller.shouldOfferPrompt)

        // '표시하는 순간' 가드를 세운다 → 이후에는 제안하지 않는다(버튼을 누르지 않아도).
        controller.markPromptShown()
        XCTAssertFalse(controller.shouldOfferPrompt)
    }

    func testPromptNotOfferedWhenReminderAlreadyEnabled() async {
        let defaults = makeDefaults(enabled: true, promptShown: false)
        let center = FakeNotificationScheduler()
        let scheduler = makeScheduler(center: center, defaults: defaults)
        let controller = NightReminderController(scheduler: scheduler, center: center, defaults: defaults)

        XCTAssertFalse(controller.shouldOfferPrompt)
    }

    func testAcceptPromptEnablesAndSchedules() async {
        let defaults = makeDefaults(enabled: false, promptShown: false)
        let center = FakeNotificationScheduler(status: .notDetermined, requestResult: true)
        let scheduler = makeScheduler(center: center, defaults: defaults)
        let controller = NightReminderController(scheduler: scheduler, center: center, defaults: defaults)

        controller.markPromptShown()
        await controller.acceptPrompt()

        XCTAssertTrue(controller.isEnabled)
        XCTAssertEqual(center.requestCount, 1)
        XCTAssertEqual(center.scheduled.count, 7)
    }

    // MARK: - 토글 켜기: 권한 거부 시 꺼진 채 안내

    func testEnableToggleWithDeniedPermissionShowsNotice() async {
        let defaults = makeDefaults(enabled: false, promptShown: true)
        let center = FakeNotificationScheduler(status: .denied)
        let scheduler = makeScheduler(center: center, defaults: defaults)
        let controller = NightReminderController(scheduler: scheduler, center: center, defaults: defaults)

        await controller.setEnabled(true)

        XCTAssertFalse(controller.isEnabled)
        XCTAssertTrue(controller.showPermissionDeniedNotice)
        XCTAssertTrue(center.scheduled.isEmpty)
    }

    // MARK: - 포그라운드 복귀: 권한 꺼졌으면 토글 off

    func testRefreshFromSystemTurnsOffWhenPermissionRevoked() async {
        let defaults = makeDefaults(enabled: true, promptShown: true)
        let center = FakeNotificationScheduler(status: .denied)
        let scheduler = makeScheduler(center: center, defaults: defaults)
        let controller = NightReminderController(scheduler: scheduler, center: center, defaults: defaults)

        await controller.refreshFromSystem()

        XCTAssertFalse(controller.isEnabled)
        XCTAssertTrue(center.scheduled.isEmpty)
    }
}
