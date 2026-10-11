//
//  AppSettings.swift
//  BlueHour
//
//  UserDefaults에 저장하는 설정값의 키와 기본값을 한곳에 모은다.
//  (설정 화면과 녹음 흐름이 같은 키·기본값을 공유하도록)
//

import Foundation

enum AppSettings {

    enum Keys {
        /// Face ID 잠금 사용 여부
        static let useFaceIDLock = "settings.useFaceIDLock"
        /// 원본 음성을 기기에 보관할지 여부 ('목소리 남기기')
        static let saveOriginalAudio = "settings.saveOriginalAudio"
        /// 첫 실행 안내를 끝까지 마쳤는지 여부
        static let hasCompletedOnboarding = "settings.hasCompletedOnboarding"
        /// 무료 한도(30번째 하늘) 안내를 결과 카드에서 이미 한 번 보여줬는지 여부
        static let hasShownFreeLimitNotice = "settings.hasShownFreeLimitNotice"
        /// 밤 리마인더 알림 켜짐 여부 (F-LDUDEX)
        static let reminderEnabled = "settings.reminderEnabled"
        /// 밤 리마인더 알림 시각 (시). 기본 22시
        static let reminderHour = "settings.reminderHour"
        /// 밤 리마인더 알림 시각 (분). 기본 30분 → 기본 22:30
        static let reminderMinute = "settings.reminderMinute"
        /// 첫 기록 결과 화면에서 밤 리마인더 제안을 이미 한 번 표시했는지 여부
        static let hasShownReminderPrompt = "settings.hasShownReminderPrompt"
    }

    /// 앱 시작 시 한 번 호출해 기본값을 등록한다.
    /// 음성 저장 방식의 초기값은 F-SRJTXF 기획대로 '목소리 남기기'(true)이며,
    /// 첫 실행 안내에서 사용자가 고른 값으로 이 초기값을 덮어쓴다.
    static func registerDefaults(_ defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            Keys.saveOriginalAudio: true,
            Keys.useFaceIDLock: false,
            Keys.hasCompletedOnboarding: false,
            Keys.hasShownFreeLimitNotice: false,
            Keys.reminderEnabled: false,
            Keys.reminderHour: 22,
            Keys.reminderMinute: 30,
            Keys.hasShownReminderPrompt: false
        ])
    }
}
