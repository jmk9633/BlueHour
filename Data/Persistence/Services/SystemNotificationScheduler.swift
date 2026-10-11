//
//  SystemNotificationScheduler.swift
//  BlueHour
//
//  NotificationScheduling의 실제 구현. UNUserNotificationCenter로 로컬 알림을 예약한다.
//  앱 아이콘 배지는 쓰지 않으므로 권한도 [.alert, .sound]만 요청한다. (PL-OZYYZI)
//

import Foundation
import UserNotifications

@MainActor
final class SystemNotificationScheduler: NotificationScheduling {

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> NotificationAuthStatus {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            // provisional·ephemeral도 알림을 전달할 수 있으므로 예약 가능으로 본다.
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func pendingReminderIdentifiers() async -> [String] {
        let requests = await center.pendingNotificationRequests()
        return requests
            .map(\.identifier)
            .filter { $0.hasPrefix(NightReminderScheduler.identifierPrefix) }
    }

    func removeReminders(identifiers: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func scheduleReminder(identifier: String, body: String, at components: DateComponents) async {
        let content = UNMutableNotificationContent()
        // 제목은 비워 iOS가 헤더에 앱 이름을 표시하게 하고, 본문에만 초대 문구를 둔다.
        content.body = body
        content.sound = .default
        // 앱 아이콘 배지는 사용하지 않는다.

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
