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
    }

    /// 앱 시작 시 한 번 호출해 기본값을 등록한다.
    /// 음성 저장 방식의 초기값은 '목소리 남기기'(true)로 둔다.
    /// (첫 실행 안내에서 사용자가 고르는 흐름은 5단계에서 추가)
    static func registerDefaults(_ defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            Keys.saveOriginalAudio: true,
            Keys.useFaceIDLock: false
        ])
    }
}
