//
//  ReminderNotificationDelegate.swift
//  BlueHour
//
//  밤 리마인더 알림을 눌렀을 때 오늘 탭으로 열고(F-LDUDEX),
//  앱을 쓰는 중(포그라운드)에 알림 시각이 되면 배너를 띄우지 않도록 처리한다.
//  Face ID 잠금은 RootView 오버레이가 독립적으로 처리하므로 여기서는 탭만 바꾼다.
//

import Foundation
import UserNotifications

/// 탭 선택을 공유하기 위한 아주 작은 라우터. 알림 탭 시 오늘 탭(0)으로 바꾼다.
@MainActor
@Observable
final class TabRouter {
    /// 현재 선택된 탭 인덱스. 오늘=0, 하늘=1, 나=2.
    var selection: Int = 0

    static let todayTab = 0
}

/// UNUserNotificationCenterDelegate 구현. 탭 전환만 담당한다.
final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    private let tabRouter: TabRouter

    init(tabRouter: TabRouter) {
        self.tabRouter = tabRouter
        super.init()
    }

    /// 포그라운드에서 알림 시각이 되면 배너를 띄우지 않는다(빈 옵션 반환).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }

    /// 알림을 누르면 오늘 탭으로 연다. (잠금은 RootView가 자동으로 먼저 요구한다.)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // TabRouter는 @MainActor 클래스라 Sendable이다. self를 캡처하지 않도록 지역 변수로 넘긴다.
        let router = tabRouter
        await MainActor.run {
            router.selection = TabRouter.todayTab
        }
    }
}
