//
//  NightReminderScheduling.swift
//  BlueHour
//
//  밤 리마인더 알림(F-LDUDEX / PL-OZYYZI)의 추상화.
//  UNUserNotificationCenter를 바깥으로 노출하지 않고 프로토콜로 감싸 Fake로 테스트한다.
//

import Foundation

/// iOS 알림 권한 상태. provisional·ephemeral은 '예약 가능'이므로 authorized로 합친다.
enum NotificationAuthStatus {
    case authorized
    case denied
    case notDetermined
}

/// 로컬 알림 예약을 담당하는 창구. 실제 구현은 UNUserNotificationCenter(SystemNotificationScheduler),
/// 테스트는 Fake가 대신한다.
@MainActor
protocol NotificationScheduling: AnyObject {
    /// 현재 알림 권한 상태.
    func authorizationStatus() async -> NotificationAuthStatus
    /// 알림 권한을 요청한다. 허용되면 true.
    func requestAuthorization() async -> Bool
    /// 우리(밤 리마인더)가 예약해 둔 알림 식별자들.
    func pendingReminderIdentifiers() async -> [String]
    /// 주어진 식별자의 예약을 모두 지운다.
    func removeReminders(identifiers: [String]) async
    /// 지정한 날짜 구성요소(년·월·일·시·분)에 1회성 알림을 예약한다.
    func scheduleReminder(identifier: String, body: String, at components: DateComponents) async
}

/// 밤 리마인더의 재예약과 첫 기록 제안을 화면(ViewModel)이 쓰는 창구.
/// 실제 구현은 NightReminderController, 테스트는 Fake가 대신한다.
@MainActor
protocol NightReminding: AnyObject {
    /// 첫 기록 결과 화면에서 알림 제안을 보여줄지. (아직 제안한 적 없고 리마인더도 꺼져 있을 때)
    var shouldOfferPrompt: Bool { get }
    /// 제안을 '화면에 표시했다'고 기록한다. 버튼을 누르지 않고 닫아도 다시 뜨지 않게 한다.
    func markPromptShown()
    /// 제안에서 [알려주세요]를 눌렀을 때. 권한을 요청하고 허용되면 리마인더를 켜고 예약한다.
    func acceptPrompt() async
    /// 제안에서 [괜찮아요]를 눌렀을 때. 아무 동작도 하지 않는다(가드는 표시 시점에 이미 기록됨).
    func declinePrompt()
    /// 예약을 다시 맞춘다(기존 예약을 모두 지우고 기록 없는 날에 새로 예약).
    func reschedule() async
}
