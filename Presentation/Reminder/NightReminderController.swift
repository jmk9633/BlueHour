//
//  NightReminderController.swift
//  BlueHour
//
//  밤 리마인더(F-LDUDEX)의 화면용 상태와 동작을 담는 컨트롤러.
//  나 탭 토글·시간, 첫 기록 제안, 포그라운드 복귀 시 권한 반영을 담당하고,
//  실제 예약 계산은 NightReminderScheduler에 위임한다.
//

import Foundation
import Observation

@MainActor
@Observable
final class NightReminderController: NightReminding {

    /// 밤 리마인더가 켜져 있는지(나 탭 토글 상태).
    private(set) var isEnabled: Bool

    /// 토글을 켜려 했지만 iOS 알림 권한이 꺼져 있을 때 true. 화면이 '설정 열기' 안내를 띄운다.
    var showPermissionDeniedNotice = false

    private let scheduler: NightReminderScheduler
    private let center: NotificationScheduling
    private let defaults: UserDefaults

    init(
        scheduler: NightReminderScheduler,
        center: NotificationScheduling,
        defaults: UserDefaults = .standard
    ) {
        self.scheduler = scheduler
        self.center = center
        self.defaults = defaults
        self.isEnabled = defaults.bool(forKey: AppSettings.Keys.reminderEnabled)
    }

    // MARK: - 알림 시간

    var reminderHour: Int { defaults.integer(forKey: AppSettings.Keys.reminderHour) }
    var reminderMinute: Int { defaults.integer(forKey: AppSettings.Keys.reminderMinute) }

    // MARK: - 첫 기록 제안 (F-FJEWRI / F-LLFPXL 연동)

    /// 첫 기록 결과 화면에서 제안을 보여줄지. 아직 제안한 적 없고(hasShownReminderPrompt=false),
    /// 리마인더도 꺼져 있을 때만 보여준다.
    var shouldOfferPrompt: Bool {
        !defaults.bool(forKey: AppSettings.Keys.hasShownReminderPrompt) && !isEnabled
    }

    /// 제안이 화면에 표시되는 순간 호출한다. 버튼을 누르지 않고 닫아도 다시 뜨지 않게 가드를 세운다.
    func markPromptShown() {
        defaults.set(true, forKey: AppSettings.Keys.hasShownReminderPrompt)
    }

    /// [알려주세요]: 권한을 요청하고, 허용되면 리마인더를 켜고 예약한다.
    func acceptPrompt() async {
        let granted = await ensureAuthorized()
        if granted {
            setEnabledValue(true)
            await scheduler.reschedule()
        }
        // 거부되면 리마인더는 켜지 않는다. (가드는 표시 시점에 이미 세워져 다시 제안하지 않는다.)
    }

    /// [괜찮아요]: 아무 동작도 하지 않는다. (가드는 표시 시점에 이미 세워져 있다.)
    func declinePrompt() {}

    // MARK: - 나 탭 토글 / 시간 변경

    /// 토글 조작. 켤 때는 권한을 확인·요청하고, 꺼져 있으면 안내만 띄운 채 꺼진 상태로 둔다.
    func setEnabled(_ on: Bool) async {
        guard on else {
            setEnabledValue(false)
            await scheduler.reschedule()   // 예약을 모두 지운다.
            return
        }
        let granted = await ensureAuthorized()
        if granted {
            setEnabledValue(true)
            await scheduler.reschedule()
        } else {
            setEnabledValue(false)
            showPermissionDeniedNotice = true
        }
    }

    /// 알림 시간 변경 후 재예약.
    func setTime(hour: Int, minute: Int) async {
        defaults.set(hour, forKey: AppSettings.Keys.reminderHour)
        defaults.set(minute, forKey: AppSettings.Keys.reminderMinute)
        await scheduler.reschedule()
    }

    // MARK: - 앱 실행 / 포그라운드 복귀

    /// 포그라운드 복귀 시: iOS 설정에서 권한이 꺼졌으면 토글을 꺼진 상태로 표시하고, 예약을 다시 맞춘다.
    func refreshFromSystem() async {
        if isEnabled, await center.authorizationStatus() != .authorized {
            setEnabledValue(false)
        }
        await scheduler.reschedule()
    }

    /// 구매 완료 등으로 예약만 다시 맞추면 될 때.
    func reschedule() async {
        await scheduler.reschedule()
    }

    // MARK: - 내부

    /// 권한이 허용 상태가 되도록 한다. 미결정이면 요청하고, 이미 거부면 false.
    private func ensureAuthorized() async -> Bool {
        switch await center.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await center.requestAuthorization()
        case .denied:
            return false
        }
    }

    private func setEnabledValue(_ value: Bool) {
        isEnabled = value
        defaults.set(value, forKey: AppSettings.Keys.reminderEnabled)
    }
}
